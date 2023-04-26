module mem_ram_sdp_core
    import mem_pkg::*;
#(
    parameter mem_rd_mode_t MEM_RD_MODE = STD,
    parameter int ADDR_WID = 8,
    parameter int DATA_WID = 32,
    parameter bit ASYNC = 0,
    parameter bit RESET_FSM = 0,
    parameter bit [DATA_WID-1:0] RESET_VAL = '0,
    parameter xilinx_ram_style_t _RAM_STYLE = RAM_STYLE_AUTO,
    parameter bit SIM__FAST_INIT = 0 // Optimize sim time
) (
    // Write interface
    input logic            wr_clk,
    input logic            wr_srst,
    mem_intf.wr_peripheral mem_wr_if,

    // Read interface
    input logic            rd_clk,
    input logic            rd_srst,
    mem_intf.rd_peripheral mem_rd_if,

    // Init status
    output logic           init_done
);

    // -----------------------------
    // PARAMETERS
    // -----------------------------
    localparam int DEPTH = 2**ADDR_WID;

    // RAM style is auto-determined by size.
    // Method below is workaround for lack of Vivado support for 'string' datatype.
    // Return RAM style as enumerated type and then convert to (untyped) 'string' representation:
    localparam xilinx_ram_style_t __RAM_STYLE = _RAM_STYLE == RAM_STYLE_AUTO ? get_default_ram_style(DEPTH, DATA_WID, ASYNC) : _RAM_STYLE;
    localparam RAM_STYLE_STR = __RAM_STYLE == RAM_STYLE_DISTRIBUTED ? "distributed" :
                               __RAM_STYLE == RAM_STYLE_BLOCK       ? "block" :
                               __RAM_STYLE == RAM_STYLE_REGISTERS   ? "registers" :
                                                                      "ultra";
    // NOTE: Additional pipelining (write and/or read) may be required for large memory arrays
    localparam int WR_PIPELINE_STAGES = get_default_wr_pipeline_stages(__RAM_STYLE);
    localparam int RD_PIPELINE_STAGES = get_default_rd_pipeline_stages(__RAM_STYLE);

    // -----------------------------
    // TYPEDEFS
    // -----------------------------
    typedef logic [ADDR_WID-1:0] addr_t;
    typedef logic [DATA_WID-1:0] data_t;

    // -----------------------------
    // INTERFACES
    // -----------------------------
    mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if__int (.clk(wr_clk));

    // -----------------------------
    // SIGNALS
    // -----------------------------
    logic  wr_srst_local;
    logic  wr_en;
    logic  wr_req;
    addr_t wr_addr;
    data_t wr_data;

    logic  rd_srst_local;
    logic  rd;
    addr_t rd_addr;
    data_t rd_data;

    (* ram_style = RAM_STYLE_STR *) data_t mem [DEPTH];

    // -----------------------------
    // Reset FSM (optional)
    // -----------------------------
    generate
        if (RESET_FSM) begin : g__reset_fsm
            // Reset FSM
            // - on reset deassertion, auto-clears memory by
            //   sequentially writing '0 to each memory element
            mem_reset_fsm     #(
                .ADDR_WID      ( ADDR_WID ),
                .DATA_WID      ( DATA_WID ),
                .RESET_VAL     ( RESET_VAL ),
                .SIM__FAST_INIT( SIM__FAST_INIT )
            ) i_mem_reset_fsm  (
                .wr_clk        ( wr_clk ),
                .wr_srst       ( wr_srst ),
                .init_done     ( init_done ),
                .mem_wr_if_in  ( mem_wr_if ),
                .mem_wr_if_out ( mem_wr_if__int )
            );
        end : g__reset_fsm
        else begin : g__no_reset_fsm
            // No reset FSM
            // - drive write interface directly
            //   (pass write interface along unmodified)
            mem_wr_intf_connector i_mem_wr_intf_connector (
                .mem_wr_if_from_controller ( mem_wr_if ),
                .mem_wr_if_to_peripheral   ( mem_wr_if__int )
            );
            assign init_done = mem_wr_if__int.rdy;
        end : g__no_reset_fsm
    endgenerate

    // -----------------------------
    // RAM (infers simple dual-port)
    // -----------------------------
    initial mem = '{DEPTH{{DATA_WID{1'b0}}}};
    always @(posedge wr_clk) begin
`ifdef SIMULATION
        if (SIM__FAST_INIT && RESET_FSM && mem_wr_if__int.rst) begin
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= RESET_VAL;
            end
        end else
`endif
        if (wr_en) begin
            if (wr_req) mem[wr_addr] <= wr_data;
        end
    end
    always @(posedge rd_clk) begin
        if (rd) rd_data <= mem[rd_addr];
    end

    // -----------------------------
    // Write-side logic
    // -----------------------------
    // Combine block/'soft' resets
    initial wr_srst_local = 1'b0;
    always @(posedge wr_clk) begin
        if (wr_srst || mem_wr_if__int.rst) wr_srst_local <= 1'b1;
        else                               wr_srst_local <= 1'b0;
    end

    // Unless held in reset, memory is always ready to receive transactions
    assign mem_wr_if__int.rdy = !wr_srst_local;

    // Write pipelining
    generate
        if (WR_PIPELINE_STAGES > 0) begin : g__wr_pipe
            logic  wr_en_p   [WR_PIPELINE_STAGES];
            logic  wr_req_p  [WR_PIPELINE_STAGES];
            addr_t wr_addr_p [WR_PIPELINE_STAGES];
            data_t wr_data_p [WR_PIPELINE_STAGES];

            // Control pipeline
            initial begin
                wr_en_p  = '{WR_PIPELINE_STAGES{1'b0}};
                wr_req_p = '{WR_PIPELINE_STAGES{1'b0}};
            end
            always @(posedge wr_clk) begin
                for (int i = 1; i < WR_PIPELINE_STAGES; i++) begin
                    wr_en_p[i]  <= wr_en_p[i-1];
                    wr_req_p[i] <= wr_req_p[i-1];
                end
                wr_en_p[0]  <= mem_wr_if__int.en;
                wr_req_p[0] <= mem_wr_if__int.req;
            end

            // Data pipeline
            initial begin
                wr_addr_p = '{WR_PIPELINE_STAGES{'0}};
                wr_data_p = '{WR_PIPELINE_STAGES{'0}};
            end
            always @(posedge wr_clk) begin
                for (int i = 1; i < WR_PIPELINE_STAGES; i++) begin
                    wr_addr_p[i] <= wr_addr_p[i-1];
                    wr_data_p[i] <= wr_data_p[i-1];
                end
                wr_addr_p[0] <= mem_wr_if__int.addr;
                wr_data_p[0] <= mem_wr_if__int.data;
            end

            assign wr_en   = wr_en_p  [WR_PIPELINE_STAGES-1];
            assign wr_req  = wr_req_p [WR_PIPELINE_STAGES-1];
            assign wr_addr = wr_addr_p[WR_PIPELINE_STAGES-1];
            assign wr_data = wr_data_p[WR_PIPELINE_STAGES-1];
        end : g__wr_pipe
        else if (WR_PIPELINE_STAGES == 0) begin : g__wr_no_pipe
            // No additional pipelining (drive memory write interface directly)
            assign wr_en   = !wr_srst_local && mem_wr_if__int.en;
            assign wr_req  = mem_wr_if__int.req;
            assign wr_addr = mem_wr_if__int.addr;
            assign wr_data = mem_wr_if__int.data;
        end : g__wr_no_pipe
    endgenerate

    // Ack writes immediately
    initial mem_wr_if__int.ack = 1'b0;
    always @(posedge wr_clk) begin
        if (wr_srst_local)        mem_wr_if__int.ack <= 1'b0;
        else if (wr_en && wr_req) mem_wr_if__int.ack <= 1'b1;
        else                      mem_wr_if__int.ack <= 1'b0;
    end

    // -----------------------------
    // Read-side logic
    // -----------------------------
    // Combine block/'soft' resets
    initial rd_srst_local = 1'b0;
    always @(posedge rd_clk) begin
        if (rd_srst || mem_rd_if.rst) rd_srst_local <= 1'b1;
        else                          rd_srst_local <= 1'b0;
    end

    assign rd      = mem_rd_if.req;
    assign rd_addr = mem_rd_if.addr;

    // Unless held in reset, memory is always ready to receive transactions
    assign mem_rd_if.rdy = !rd_srst_local;

    // Read pipelining
    generate
        if (RD_PIPELINE_STAGES > 0) begin : g__rd_pipe
            logic  rd_en_p   [RD_PIPELINE_STAGES+1];
            logic  rd_req_p  [RD_PIPELINE_STAGES+1];
            data_t rd_data_p [RD_PIPELINE_STAGES];

            // Enable pipeline (read data returned after RD_PIPELINE_STAGES + 1 cycles)
            always @(posedge rd_clk) begin
                for (int i = 1; i < RD_PIPELINE_STAGES+1; i++) begin
                    rd_en_p[i] <= rd_en_p[i-1];
                end
                rd_en_p[0] <= rd;
            end

            // Data pipeline
            always @(posedge rd_clk) begin
                if (MEM_RD_MODE == FWFT) begin
                   for (int i = 1; i < RD_PIPELINE_STAGES; i++) rd_data_p[i] <= rd ? rd_data_p[i-1] : rd_data_p[i];
                   rd_data_p[0] <= rd ? rd_data : rd_data_p[0];
                end 
                else if (MEM_RD_MODE == STD) begin
                   for (int i = 1; i < RD_PIPELINE_STAGES; i++) rd_data_p[i] <= rd_en_p[i] ? rd_data_p[i-1] : rd_data_p[i];
                   rd_data_p[0] <= rd_en_p[0] ? rd_data : rd_data_p[0];
                end
            end
            assign mem_rd_if.data = rd_data_p[RD_PIPELINE_STAGES-1];

            // Req pipeline
            initial rd_req_p = '{RD_PIPELINE_STAGES+1{1'b0}};
            always @(posedge rd_clk) begin
                if (rd_srst_local) rd_req_p <= '{RD_PIPELINE_STAGES+1{1'b0}};
                else begin
                    for (int i = 1; i < RD_PIPELINE_STAGES+1; i++) begin
                        rd_req_p[i] <= rd_req_p[i-1];
                    end
                    rd_req_p[0] <= rd;
                end
            end
            assign mem_rd_if.ack = rd_req_p[RD_PIPELINE_STAGES];

        end : g__rd_pipe
        else begin : g__rd_no_pipe
            // No additional pipelining (read data returned after 1 cycle)
            initial mem_rd_if.ack = 1'b0;
            always @(posedge rd_clk) begin
                if (rd_srst_local) mem_rd_if.ack <= 1'b0;
                else               mem_rd_if.ack <= rd;
            end
            assign mem_rd_if.data = rd_data;
        end : g__rd_no_pipe
    endgenerate

endmodule : mem_ram_sdp_core
