module fifo_core
    import fifo_pkg::*;
#(
    parameter type DATA_T = logic[15:0],
    parameter int DEPTH = 4,
    parameter bit ASYNC = 1,
    parameter bit FWFT = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    parameter opt_mode_t WR_OPT_MODE = fifo_pkg::OPT_MODE_TIMING,
    parameter opt_mode_t RD_OPT_MODE = fifo_pkg::OPT_MODE_TIMING,
    // Derived parameters (don't override)
    parameter int CNT_WID = FWFT ? $clog2(DEPTH+1+1) : $clog2(DEPTH+1)
) (
    // Write interface
    input  logic                wr_clk,
    input  logic                wr_srst,
    output logic                wr_rdy,
    input  logic                wr,
    input  DATA_T               wr_data,
    output logic [CNT_WID-1:0]  wr_count,
    output logic                wr_full,
    output logic                wr_oflow,

    // Read interface
    input  logic                rd_clk,
    input  logic                rd_srst,
    input  logic                rd,
    output logic                rd_ack,
    output DATA_T               rd_data,
    output logic [CNT_WID-1:0]  rd_count,
    output logic                rd_empty,
    output logic                rd_uflow,

    // Monitoring
    fifo_wr_mon_intf.peripheral wr_mon_if,
    fifo_rd_mon_intf.peripheral rd_mon_if
);

    // -----------------------------
    // Imports
    // -----------------------------
    import mem_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int PTR_WID = $clog2(DEPTH);
    localparam int MEM_DEPTH = 2**PTR_WID;
    localparam int __CNT_WID = $clog2(DEPTH+1);

    localparam int DATA_WID = $bits(DATA_T);

    localparam bit __UFLOW_PROT = FWFT ? 1 : UFLOW_PROT;

    // Select memory optimization mode
    // - in FWFT mode, the code assumes that the memory instance includes no read pipelining,
    //   i.e. the read data is available on the cycle following a read request; select a memory
    //   implementation optimized for low-latency in FWFT mode.
    localparam mem_pkg::opt_mode_t MEM_OPT_MODE = FWFT ? mem_pkg::OPT_MODE_LATENCY : mem_pkg::OPT_MODE_DEFAULT;

    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID: PTR_WID,
        DATA_WID: DATA_WID,
        ASYNC: ASYNC,
        RESET_FSM: 0,
        OPT_MODE: MEM_OPT_MODE
    };
    localparam int MEM_WR_LATENCY = mem_pkg::get_wr_latency(MEM_SPEC);
    localparam int MEM_RD_LATENCY = mem_pkg::get_rd_latency(MEM_SPEC);

    // Check parameters
    initial begin
        std_pkg::param_check(MEM_WR_LATENCY, 1, "MEM_WR_LATENCY", "fifo_core expects memory write latency == 1");
        if (FWFT) std_pkg::param_check(MEM_RD_LATENCY, 1, "MEM_RD_LATENCY", "fifo_core expects memory read latency == 1 for FWFT mode");
    end

    // -----------------------------
    // Signals
    // -----------------------------
    logic                 local_wr_srst;
    logic                 local_rd_srst;

    logic                 wr_safe;
    logic [PTR_WID-1:0]   wr_ptr;
    logic [__CNT_WID-1:0] __wr_count;

    logic                 rd_safe;
    logic [PTR_WID-1:0]   rd_ptr;
    logic                 __rd;
    logic                 __rd_empty;
    logic [__CNT_WID-1:0] __rd_count;
    logic                 __rd_uflow;

    logic mem_init_done;

    // -----------------------------
    // Interfaces
    // -----------------------------
    mem_wr_intf #(.ADDR_WID (PTR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(wr_clk));
    mem_rd_intf #(.ADDR_WID (PTR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(rd_clk));

    // -----------------------------
    // Resets
    // -----------------------------
    // Combine wr/rd resets to avoid inconsistent state between write and read sides
    generate
        if (ASYNC) begin : g__async
            // (Local) signals
            logic __wr_srst;
            logic __rd_srst;
            logic wr_srst__rd_clk;
            logic rd_srst__wr_clk;

            // Register to eliminate fanout on synchronizer input
            always_ff @(posedge wr_clk) __wr_srst <= wr_srst;

            // Synchronize write reset to read domain
            sync_reset #(
                .INPUT_ACTIVE_HIGH (1)
            ) i_sync_reset__wr_srst__rd_clk (
                .clk_in  ( wr_clk ),
                .rst_in  ( __wr_srst ),
                .clk_out ( rd_clk ),
                .rst_out ( wr_srst__rd_clk )
            );

            // Register to eliminate fanout on synchronizer input
            always_ff @(posedge rd_clk) __rd_srst <= rd_srst;

            // Synchronize read reset to write domain
            sync_reset #(
                .INPUT_ACTIVE_HIGH (1)
            ) i_sync_reset__rd_srst__wr_clk (
                .clk_in  ( rd_clk ),
                .rst_in  ( __rd_srst ),
                .clk_out ( wr_clk ),
                .rst_out ( rd_srst__wr_clk )
            );

            // Synthesize local resets
            initial local_wr_srst = 1'b1;
            always @(posedge wr_clk) begin
                if (wr_srst || rd_srst__wr_clk) local_wr_srst <= 1'b1;
                else                            local_wr_srst <= 1'b0;
            end

            initial local_rd_srst = 1'b1;
            always @(posedge rd_clk) begin
                if (rd_srst || wr_srst__rd_clk) local_rd_srst <= 1'b1;
                else                            local_rd_srst <= 1'b0;
            end
        end : g__async
        else begin : g__sync
            // Synthesize local reset (no synchronization necessary)
            initial local_wr_srst = 1'b1;
            always @(posedge wr_clk) begin
                if (wr_srst || rd_srst) local_wr_srst <= 1'b1;
                else                    local_wr_srst <= 1'b0;
            end
            assign local_rd_srst = local_wr_srst;
        end : g__sync
    endgenerate

    // -----------------------------
    // SDP RAM Instance
    // -----------------------------
    mem_ram_sdp #(
        .SPEC    ( MEM_SPEC )
    ) i_mem_ram_sdp (
        .mem_wr_if ( mem_wr_if ),
        .mem_rd_if ( mem_rd_if )
    );

    assign mem_init_done = mem_wr_if.rdy;

    // -----------------------------
    // Control FSM
    // -----------------------------
    fifo_ctrl_fsm  #(
        .DEPTH      ( DEPTH ),
        .ASYNC      ( ASYNC ),
        .OFLOW_PROT ( OFLOW_PROT ),
        .UFLOW_PROT ( __UFLOW_PROT ),
        .WR_OPT_MODE( WR_OPT_MODE ),
        .RD_OPT_MODE( RD_OPT_MODE )
    ) i_fifo_ctrl_fsm (
        .wr_clk   ( wr_clk ),
        .wr_srst  ( local_wr_srst ),
        .wr_rdy   ( wr_rdy ),
        .wr       ( wr ),
        .wr_safe  ( wr_safe ),
        .wr_ptr   ( wr_ptr ),
        .wr_count ( __wr_count ),
        .wr_full  ( wr_full ),
        .wr_oflow ( wr_oflow ),
        .rd_clk   ( rd_clk ),
        .rd_srst  ( local_rd_srst ),
        .rd       ( __rd ),
        .rd_safe  ( rd_safe ),
        .rd_ptr   ( rd_ptr ),
        .rd_count ( __rd_count ),
        .rd_empty ( __rd_empty ),
        .rd_uflow ( __rd_uflow ),
        .mem_rdy  ( mem_init_done )
    );

    // -----------------------------
    // Data memory interface
    // -----------------------------
    assign mem_wr_if.rst = 1'b0;
    assign mem_wr_if.en = 1'b1;
    assign mem_wr_if.req = wr_safe;
    assign mem_wr_if.addr = wr_ptr;
    assign mem_wr_if.data = wr_data;

    assign mem_rd_if.rst = 1'b0;
    assign mem_rd_if.req = rd_safe;
    assign mem_rd_if.addr = rd_ptr;
    assign rd_data = mem_rd_if.data;

    generate
        // First-word fall-through FIFO mode
        if (FWFT) begin : g__fwft
            // empty indication reflects presence/absence of data in output register
            initial rd_empty = 1'b1;
            always @(posedge rd_clk) begin
                if (local_rd_srst)    rd_empty <= 1'b1;
                else if (!__rd_empty) rd_empty <= 1'b0;
                else if (rd)          rd_empty <= 1'b1;
            end

            // Adjust count for entry in FWFT buffer
            assign rd_count = rd_empty ? __rd_count : __rd_count + 1;

            // Data prefetch
            assign __rd = rd_empty || rd;

            assign rd_ack  = !rd_empty;

            // Underflow
            assign rd_uflow = rd && rd_empty;

        end : g__fwft

        // Standard FIFO mode
        else begin : g__std
            assign __rd = rd;
            assign rd_ack   = mem_rd_if.ack;
            assign rd_count = __rd_count;
            assign rd_empty = __rd_empty;
            assign rd_uflow = __rd_uflow;
        end : g__std
    endgenerate

    // Write count
    assign wr_count = __wr_count;

    // Export monitor data
    assign wr_mon_if.reset = local_wr_srst;
    assign wr_mon_if.full  = wr_full;
    assign wr_mon_if.oflow = wr_oflow;
    assign wr_mon_if.count = {'0, wr_count};
    assign wr_mon_if.ptr   = {'0, wr_ptr};

    assign rd_mon_if.reset = local_rd_srst;
    assign rd_mon_if.empty = rd_empty;
    assign rd_mon_if.uflow = rd_uflow;
    assign rd_mon_if.count = {'0, rd_count};
    assign rd_mon_if.ptr   = {'0, rd_ptr};
  
endmodule : fifo_core
