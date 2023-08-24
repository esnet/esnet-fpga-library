module fifo_ctrl_fsm #(
    parameter int DEPTH = 256,
    parameter bit ASYNC = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    parameter fifo_pkg::opt_mode_t WR_OPT_MODE = fifo_pkg::OPT_MODE_TIMING,
    parameter fifo_pkg::opt_mode_t RD_OPT_MODE = fifo_pkg::OPT_MODE_TIMING,
    // Derived parameters (don't override)
    parameter int PTR_WID = DEPTH > 1 ? $clog2(DEPTH) : 1,
    parameter int CNT_WID = $clog2(DEPTH+1),
    // Debug parameters
    parameter bit AXIL_IF = 1'b0,
    parameter bit DEBUG_ILA = 1'b0
) (
    // Write side
    input  logic               wr_clk,
    input  logic               wr_srst,
    output logic               wr_rdy,
    input  logic               wr,
    output logic               wr_safe,
    output logic [PTR_WID-1:0] wr_ptr,
    output logic [CNT_WID-1:0] wr_count,
    output logic               wr_full,
    output logic               wr_oflow,

    // Read side
    input  logic               rd_clk,
    input  logic               rd_srst,
    input  logic               rd,
    output logic               rd_safe,
    output logic [PTR_WID-1:0] rd_ptr,
    output logic [CNT_WID-1:0] rd_count,
    output logic               rd_empty,
    output logic               rd_uflow,

    // Memory ready
    input  logic               mem_rdy,

    // AXI-L control/monitoring interface
    axi4l_intf.peripheral      axil_if
);

    // -----------------------------
    // Signals
    // -----------------------------
    logic [CNT_WID-1:0] _wr_ptr;
    logic [CNT_WID-1:0] _rd_ptr;

    logic [CNT_WID-1:0] _wr_count;
    logic [CNT_WID-1:0] _rd_count;

    // -----------------------------
    // Write-side logic
    // -----------------------------
    assign wr_safe = OFLOW_PROT ? (wr && wr_rdy) : wr;

    initial _wr_ptr = 0;
    always @(posedge wr_clk) begin
        if (wr_srst)      _wr_ptr <= 0;
        else if (wr_safe) _wr_ptr <= _wr_ptr + 1;
    end

    assign wr_ptr = _wr_ptr % DEPTH;
    assign wr_oflow = wr && !wr_rdy;

    // -----------------------------
    // Read-side logic
    // -----------------------------
    assign rd_safe = UFLOW_PROT ? (rd && !rd_empty) : rd;

    initial _rd_ptr = 0;
    always @(posedge rd_clk) begin
        if (rd_srst)      _rd_ptr <= 0;
        else if (rd_safe) _rd_ptr <= _rd_ptr + 1;
    end

    assign rd_ptr = _rd_ptr % DEPTH;
    assign rd_uflow = rd && rd_empty;

    // -----------------------------
    // Count + empty/full logic
    // -----------------------------
    generate
        if (ASYNC) begin : g__async
            // (Local) signals
            logic [CNT_WID-1:0] _rd_ptr__wr_clk;
            logic [CNT_WID-1:0] _wr_ptr__rd_clk;

            // pointer synchronization
            sync_ctr #( .DATA_T(logic [CNT_WID-1:0]), .RST_VALUE(0), .DECODE_OUT(1) ) sync_wr_ptr
            (
               .clk_in       ( wr_clk ),
               .rst_in       ( wr_srst ),
               .cnt_in       ( _wr_ptr ),
               .clk_out      ( rd_clk ),
               .rst_out      ( rd_srst ),
               .cnt_out      ( _wr_ptr__rd_clk )
            );

            sync_ctr #( .DATA_T(logic [CNT_WID-1:0]), .RST_VALUE(0), .DECODE_OUT(1) ) sync_rd_ptr
            (
               .clk_in       ( rd_clk ),
               .rst_in       ( rd_srst ),
               .cnt_in       ( _rd_ptr ),
               .clk_out      ( wr_clk ),
               .rst_out      ( wr_srst ),
               .cnt_out      ( _rd_ptr__wr_clk )
            );

            assign _wr_count = _wr_ptr - _rd_ptr__wr_clk;
            assign _rd_count = _wr_ptr__rd_clk - _rd_ptr;
        end : g__async

        else begin : g__sync
            assign _wr_count = _wr_ptr - _rd_ptr;
            assign _rd_count = _wr_ptr - _rd_ptr;
        end : g__sync
    endgenerate
 
    generate
        if (WR_OPT_MODE == fifo_pkg::OPT_MODE_TIMING) begin : g__wr_opt_timing
            // wr_count/full update immediately on writes, one cycle delay on reads (write-safe)
            initial wr_count = 0;
            always @(posedge wr_clk) begin
                if (wr_srst)      wr_count <= 0;
                else if (wr_safe) wr_count <= _wr_count + 1;
                else              wr_count <= _wr_count;
            end
            initial wr_full = 0;
            always @(posedge wr_clk) begin
                if (wr_srst)      wr_full <= 1'b0;
                else if (wr_safe) wr_full <= (_wr_count >= DEPTH - 1);
                else              wr_full <= (_wr_count == DEPTH);
            end
            initial wr_rdy = 1'b0;
            always @(posedge wr_clk) begin
                if (wr_srst || !mem_rdy) wr_rdy <= 1'b0;
                else  if (wr_safe)       wr_rdy <= (_wr_count < DEPTH - 1);
                else                     wr_rdy <= (_wr_count < DEPTH);
            end
        end : g__wr_opt_timing
        else begin : g__wr_opt_latency
            // wr_count/full always updated immediately
            assign wr_count = _wr_count;
            assign wr_full = (wr_count == DEPTH);
            assign wr_rdy = mem_rdy && (wr_count < DEPTH);
        end : g__wr_opt_latency
        if (RD_OPT_MODE == fifo_pkg::OPT_MODE_TIMING) begin : g__rd_opt_timing
            // rd_count/empty updates immediately on reads, one cycle delay on writes (read-safe)
            initial rd_count = 0;
            always @(posedge rd_clk) begin
                if (rd_srst)      rd_count <= 0;
                else if (rd_safe) rd_count <= _rd_count - 1;
                else              rd_count <= _rd_count;
            end
            initial rd_empty = 1;
            always @(posedge rd_clk) begin
                if (rd_srst)      rd_empty <= 1'b1;
                else if (rd_safe) rd_empty <= (_rd_count <= 1);
                else              rd_empty <= (_rd_count == 0);
            end
        end : g__rd_opt_timing
        else begin : g__rd_opt_latency
            assign rd_count = _rd_count;
            assign rd_empty = (rd_count == 0);
        end : g__rd_opt_latency
    endgenerate
    
    // AXI-L monitoring
    generate
        if (AXIL_IF) begin : g__axil
            // (Local) imports
            import fifo_ctrl_info_reg_pkg::*;
            // (Local) interfaces
            axi4l_intf info_axil_if   ();
            axi4l_intf wr_mon_axil_if ();
            axi4l_intf rd_mon_axil_if ();
            axi4l_intf wr_mon_axil_if__wr_clk ();
            axi4l_intf rd_mon_axil_if__rd_clk ();

            fifo_ctrl_info_reg_intf   info_reg_if ();
            fifo_ctrl_wr_mon_reg_intf wr_mon_reg_if ();
            fifo_ctrl_rd_mon_reg_intf rd_mon_reg_if ();

            // FIFO block-level decoder
            fifo_ctrl_decoder i_fifo_ctrl_decoder (
                .axil_if        ( axil_if ),
                .info_axil_if   ( info_axil_if ),
                .wr_mon_axil_if ( wr_mon_axil_if ),
                .rd_mon_axil_if ( rd_mon_axil_if )
            );

            // Info block (static)
            fifo_ctrl_info_reg_blk i_fifo_ctrl_info_reg_blk (
                .axil_if    ( info_axil_if ),
                .reg_blk_if ( info_reg_if )
            );

            // Export (static) parameterization info
            assign info_reg_if.info_nxt_v = 1'b1;
            assign info_reg_if.info_nxt.fifo_type  = ASYNC      ? INFO_FIFO_TYPE_ASYNC :
                                                                  INFO_FIFO_TYPE_SYNC;
            assign info_reg_if.info_nxt.oflow_prot = OFLOW_PROT ? INFO_OFLOW_PROT_ENABLED :
                                                                  INFO_OFLOW_PROT_DISABLED;
            assign info_reg_if.info_nxt.uflow_prot = UFLOW_PROT ? INFO_UFLOW_PROT_ENABLED :
                                                                  INFO_UFLOW_PROT_DISABLED;

            assign info_reg_if.info_depth_nxt_v = 1'b1;
            assign info_reg_if.info_depth_nxt = DEPTH;

            // CDC
            axi4l_intf_cdc i_axi4l_cdc_wr_mon (
                .axi4l_if_from_controller(wr_mon_axil_if),
                .clk_to_peripheral       (wr_clk),
                .axi4l_if_to_peripheral  (wr_mon_axil_if__wr_clk)
            );
            axi4l_intf_cdc i_axi4l_cdc_rd_mon (
                .axi4l_if_from_controller(rd_mon_axil_if),
                .clk_to_peripheral       (rd_clk),
                .axi4l_if_to_peripheral  (rd_mon_axil_if__rd_clk)
            );

            // Write/read monitor register blocks
            fifo_ctrl_wr_mon_reg_blk i_fifo_ctrl_wr_mon_reg_blk (
                .axil_if    ( wr_mon_axil_if__wr_clk ),
                .reg_blk_if ( wr_mon_reg_if )
            );
            fifo_ctrl_rd_mon_reg_blk i_fifo_ctrl_rd_mon_reg_blk (
                .axil_if    ( rd_mon_axil_if__rd_clk ),
                .reg_blk_if ( rd_mon_reg_if )
            );

            // Write monitoring
            assign wr_mon_reg_if.status_nxt_v = 1'b1;
            assign wr_mon_reg_if.status_count_nxt_v = 1'b1;
            assign wr_mon_reg_if.status_wr_ptr_nxt_v = 1'b1;
            always_ff @(posedge wr_clk) begin
                wr_mon_reg_if.status_nxt.reset  <= wr_srst;
                wr_mon_reg_if.status_nxt.full   <= wr_full;
                wr_mon_reg_if.status_nxt.oflow  <= wr_oflow;
                wr_mon_reg_if.status_count_nxt  <= wr_count;
                wr_mon_reg_if.status_wr_ptr_nxt <= wr_ptr;
            end

            // Read monitoring
            assign rd_mon_reg_if.status_nxt_v = 1'b1;
            assign rd_mon_reg_if.status_count_nxt_v = 1'b1;
            assign rd_mon_reg_if.status_rd_ptr_nxt_v = 1'b1;
            always_ff @(posedge rd_clk) begin
                rd_mon_reg_if.status_nxt.reset  <= rd_srst;
                rd_mon_reg_if.status_nxt.empty  <= rd_empty;
                rd_mon_reg_if.status_nxt.uflow  <= rd_uflow;
                rd_mon_reg_if.status_count_nxt  <= rd_count;
                rd_mon_reg_if.status_rd_ptr_nxt <= rd_ptr;
            end

        end : g__axil
        else begin : g__no_axil
            // Terminate unused AXI-L interface
            axi4l_intf_peripheral_term i_axil4l_intf_peripheral_term (.axi4l_if (axil_if));
        end : g__no_axil
    endgenerate

    // Optional debug ILAs
    generate
        if (DEBUG_ILA) begin : g__ila
            fifo_xilinx_ila i_fifo_wr_ila (
                .clk (wr_clk),
                .probe0 ( wr_srst ),       // input wire [0:0]  probe0
                .probe1 ( wr_full ),       // input wire [0:0]  probe1
                .probe2 ( wr_full ),       // input wire [0:0]  probe2
                .probe3 ( wr_oflow ),      // input wire [0:0]  probe3
                .probe4 ( {'0, wr_ptr} ),  // input wire [31:0] probe4
                .probe5 ( {'0, wr_count} ) // input wire [31:0] probe5
            );
            fifo_xilinx_ila i_fifo_rd_ila (
                .clk (rd_clk),
                .probe0 ( rd_srst ),       // input wire [0:0]  probe0
                .probe1 ( rd_empty ),      // input wire [0:0]  probe1
                .probe2 ( rd_empty ),      // input wire [0:0]  probe2
                .probe3 ( rd_uflow ),      // input wire [0:0]  probe3
                .probe4 ( {'0, rd_ptr} ),  // input wire [31:0] probe4
                .probe5 ( {'0, rd_count} ) // input wire [31:0] probe5
            );
        end : g__ila
    endgenerate

endmodule : fifo_ctrl_fsm
