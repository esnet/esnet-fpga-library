// Module: packet_counters
module packet_counters #(
    parameter int PKT_CNT_WID  = 48,
    parameter int BYTE_CNT_WID = 54,
    parameter int MAX_PKT_SIZE = 16384,
    parameter bit COUNT_OK     = 1'b1,
    parameter bit COUNT_ERR    = 1'b1,
    parameter bit COUNT_OFLOW  = 1'b1,
    parameter bit COUNT_SHORT  = 1'b1,
    parameter bit COUNT_LONG   = 1'b1,
    parameter bit COUNT_OTHER  = 1'b1  // Counts packet events not counted in any other bins
                                       // - examples are:
                                       //   1. packet events with undefined status,
                                       //   2. packet events with defined status when counts are not
                                       //      implemented for those events; e.g. if only COUNT_OK and
                                       //      COUNT_OTHER are enabled, all packet events will be
                                       //      counted as either good (OK) or bad (OTHER). 
) (
    // Clock
    input  logic                      clk,

    // AXI-L
    axi4l_intf.peripheral             axil_if,

    packet_event_intf.subscriber      event_if
);
    // -------------------------------------------------
    // Imports
    // -------------------------------------------------
    import packet_pkg::*;

    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam int SIZE_WID = $clog2(MAX_PKT_SIZE+1);

    // -------------------------------------------------
    // Parameter check
    // -------------------------------------------------
    initial begin
        std_pkg::param_check_gt(PKT_CNT_WID,   1, "PKT_CNT_WID");
        std_pkg::param_check_lt(PKT_CNT_WID,  64, "PKT_CNT_WID");
        std_pkg::param_check_gt(BYTE_CNT_WID,  1, "BYTE_CNT_WID");
        std_pkg::param_check_lt(BYTE_CNT_WID, 64, "BYTE_CNT_WID");
    end

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    logic [PKT_CNT_WID-1:0]  pkt_cnt;
    logic [BYTE_CNT_WID-1:0] byte_cnt;

    logic                latch;
    logic                clear;
    logic                evt;
    logic [SIZE_WID-1:0] size;
    status_t             status;
    status_t             count_sel;

    // -------------------------------------------------
    // Interfaces
    // -------------------------------------------------
    axi4l_intf axil_if__clk ();
    packet_counters_reg_intf reg_if ();

    // -------------------------------------------------
    // AXI-L control
    // -------------------------------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    packet_counters_reg_blk i_packet_counters_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    assign reg_if.info_nxt_v = 1'b1;
    assign reg_if.info_nxt.pkt_count_wid = PKT_CNT_WID[6:0];
    assign reg_if.info_nxt.byte_count_wid = BYTE_CNT_WID[6:0];

    // -------------------------------------------------
    // Clear logic
    // -------------------------------------------------
    initial clear = 1'b1;
    always @(posedge clk) begin
        if (!axil_if__clk.aresetn) clear <= 1'b1;
        else if (reg_if.control_wr_evt && reg_if.control.clear) clear <= 1'b1;
        else                                                    clear <= 1'b0;
    end

    // -------------------------------------------------
    // Latch logic
    // -------------------------------------------------
    initial latch = 1'b0;
    always @(posedge clk) begin
        if (reg_if.control.latch == 1'b0 || reg_if.control_wr_evt) latch <= 1'b1;
        else                                                       latch <= 1'b0;
    end

    // -------------------------------------------------
    // Register events
    // -------------------------------------------------
    initial evt = 1'b0;
    always @(posedge clk) evt <= event_if.evt;

    always_ff @(posedge clk) begin
        size   <= event_if.size;
        status <= event_if.status;
    end

    // -------------------------------------------------
    // Counters
    // -------------------------------------------------
    always_comb begin
        unique case (status)
            STATUS_OK:    if (COUNT_OK)    count_sel = STATUS_OK;
            STATUS_ERR:   if (COUNT_ERR)   count_sel = STATUS_ERR;
            STATUS_OFLOW: if (COUNT_OFLOW) count_sel = STATUS_OFLOW;
            STATUS_SHORT: if (COUNT_SHORT) count_sel = STATUS_SHORT;
            STATUS_LONG:  if (COUNT_LONG)  count_sel = STATUS_LONG;
            default:                       count_sel = STATUS_UNDEFINED;
        endcase
    end

    generate
        // Count 'good' packets
        if (COUNT_OK) begin : g__ok
            // Counters
            logic [PKT_CNT_WID-1:0]  pkt_cnt;
            logic [BYTE_CNT_WID-1:0] byte_cnt;
            // Update logic
            initial begin
                pkt_cnt = '0;
                byte_cnt = '0;
            end
            always @(posedge clk) begin
                if (clear) begin
                    pkt_cnt <= '0;
                    byte_cnt <= '0;
                end
                if (evt && count_sel == STATUS_OK) begin
                    pkt_cnt <= pkt_cnt + 1;
                    byte_cnt <= byte_cnt + size;
                end
            end
            // Register assignment
            assign reg_if.cnt_pkt_ok_upper_nxt_v = latch;
            assign reg_if.cnt_pkt_ok_lower_nxt_v = latch;
            assign {reg_if.cnt_pkt_ok_upper_nxt, reg_if.cnt_pkt_ok_lower_nxt} = pkt_cnt;
            assign reg_if.cnt_byte_ok_upper_nxt_v = latch;
            assign reg_if.cnt_byte_ok_lower_nxt_v = latch;
            assign {reg_if.cnt_byte_ok_upper_nxt, reg_if.cnt_byte_ok_lower_nxt} = byte_cnt;
        end : g__ok
        // Don't count 'good' packets
        else begin : g__ok_ignored
            assign reg_if.cnt_pkt_ok_upper_nxt_v = 1'b1;
            assign reg_if.cnt_pkt_ok_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_pkt_ok_upper_nxt, reg_if.cnt_pkt_ok_lower_nxt} = 64'h0;
            assign reg_if.cnt_byte_ok_upper_nxt_v = 1'b1;
            assign reg_if.cnt_byte_ok_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_byte_ok_upper_nxt, reg_if.cnt_byte_ok_lower_nxt} = 64'h0;
        end : g__ok_ignored
    
        // Count errored packets
        if (COUNT_ERR) begin : g__err
            // Counters
            logic [PKT_CNT_WID-1:0]  pkt_cnt;
            logic [BYTE_CNT_WID-1:0] byte_cnt;
            // Update logic
            initial begin
                pkt_cnt = '0;
                byte_cnt = '0;
            end
            always @(posedge clk) begin
                if (clear) begin
                    pkt_cnt <= '0;
                    byte_cnt <= '0;
                end
                if (evt && count_sel == STATUS_ERR) begin
                    pkt_cnt <= pkt_cnt + 1;
                    byte_cnt <= byte_cnt + size;
                end
            end
            // Register assignment
            assign reg_if.cnt_pkt_err_upper_nxt_v = latch;
            assign reg_if.cnt_pkt_err_lower_nxt_v = latch;
            assign {reg_if.cnt_pkt_err_upper_nxt, reg_if.cnt_pkt_err_lower_nxt} = pkt_cnt;
            assign reg_if.cnt_byte_err_upper_nxt_v = latch;
            assign reg_if.cnt_byte_err_lower_nxt_v = latch;
            assign {reg_if.cnt_byte_err_upper_nxt, reg_if.cnt_byte_err_lower_nxt} = byte_cnt;
        end : g__err
        // Don't count errored packets
        else begin : g__err_ignored
            assign reg_if.cnt_pkt_err_upper_nxt_v = 1'b1;
            assign reg_if.cnt_pkt_err_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_pkt_err_upper_nxt, reg_if.cnt_pkt_err_lower_nxt} = 64'h0;
            assign reg_if.cnt_byte_err_upper_nxt_v = 1'b1;
            assign reg_if.cnt_byte_err_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_byte_err_upper_nxt, reg_if.cnt_byte_err_lower_nxt} = 64'h0;
        end : g__err_ignored
     
        // Count overflow packets
        if (COUNT_OFLOW) begin : g__oflow
            // Counters
            logic [PKT_CNT_WID-1:0]  pkt_cnt;
            logic [BYTE_CNT_WID-1:0] byte_cnt;
            // Update logic
            initial begin
                pkt_cnt = '0;
                byte_cnt = '0;
            end
            always @(posedge clk) begin
                if (clear) begin
                    pkt_cnt <= '0;
                    byte_cnt <= '0;
                end
                if (evt && count_sel == STATUS_OFLOW) begin
                    pkt_cnt <= pkt_cnt + 1;
                    byte_cnt <= byte_cnt + size;
                end
            end
            // Register assignment
            assign reg_if.cnt_pkt_oflow_upper_nxt_v = latch;
            assign reg_if.cnt_pkt_oflow_lower_nxt_v = latch;
            assign {reg_if.cnt_pkt_oflow_upper_nxt, reg_if.cnt_pkt_oflow_lower_nxt} = pkt_cnt;
            assign reg_if.cnt_byte_oflow_upper_nxt_v = latch;
            assign reg_if.cnt_byte_oflow_lower_nxt_v = latch;
            assign {reg_if.cnt_byte_oflow_upper_nxt, reg_if.cnt_byte_oflow_lower_nxt} = byte_cnt;
        end : g__oflow
        // Don't count overflow packets
        else begin : g__oflow_ignored
            assign reg_if.cnt_pkt_oflow_upper_nxt_v = 1'b1;
            assign reg_if.cnt_pkt_oflow_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_pkt_oflow_upper_nxt, reg_if.cnt_pkt_oflow_lower_nxt} = 64'h0;
            assign reg_if.cnt_byte_oflow_upper_nxt_v = 1'b1;
            assign reg_if.cnt_byte_oflow_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_byte_oflow_upper_nxt, reg_if.cnt_byte_oflow_lower_nxt} = 64'h0;
        end : g__oflow_ignored
     
        // Count short packets
        if (COUNT_SHORT) begin : g__short
            // Counters
            logic [PKT_CNT_WID-1:0]  pkt_cnt;
            logic [BYTE_CNT_WID-1:0] byte_cnt;
            // Update logic
            initial begin
                pkt_cnt = '0;
                byte_cnt = '0;
            end
            always @(posedge clk) begin
                if (clear) begin
                    pkt_cnt <= '0;
                    byte_cnt <= '0;
                end
                if (evt && count_sel == STATUS_SHORT) begin
                    pkt_cnt <= pkt_cnt + 1;
                    byte_cnt <= byte_cnt + size;
                end
            end
            // Register assignment
            assign reg_if.cnt_pkt_short_upper_nxt_v = latch;
            assign reg_if.cnt_pkt_short_lower_nxt_v = latch;
            assign {reg_if.cnt_pkt_short_upper_nxt, reg_if.cnt_pkt_short_lower_nxt} = pkt_cnt;
            assign reg_if.cnt_byte_short_upper_nxt_v = latch;
            assign reg_if.cnt_byte_short_lower_nxt_v = latch;
            assign {reg_if.cnt_byte_short_upper_nxt, reg_if.cnt_byte_short_lower_nxt} = byte_cnt;
        end : g__short
        // Don't count short packets
        else begin : g__short_ignored
            assign reg_if.cnt_pkt_short_upper_nxt_v = 1'b1;
            assign reg_if.cnt_pkt_short_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_pkt_short_upper_nxt, reg_if.cnt_pkt_short_lower_nxt} = 64'h0;
            assign reg_if.cnt_byte_short_upper_nxt_v = 1'b1;
            assign reg_if.cnt_byte_short_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_byte_short_upper_nxt, reg_if.cnt_byte_short_lower_nxt} = 64'h0;
        end : g__short_ignored
     
        // Count long packets
        if (COUNT_LONG) begin : g__long
            // Counters
            logic [PKT_CNT_WID-1:0]  pkt_cnt;
            logic [BYTE_CNT_WID-1:0] byte_cnt;
            // Update logic
            initial begin
                pkt_cnt = '0;
                byte_cnt = '0;
            end
            always @(posedge clk) begin
                if (clear) begin
                    pkt_cnt <= '0;
                    byte_cnt <= '0;
                end
                if (evt && count_sel == STATUS_LONG) begin
                    pkt_cnt <= pkt_cnt + 1;
                    byte_cnt <= byte_cnt + size;
                end
            end
            // Register assignment
            assign reg_if.cnt_pkt_long_upper_nxt_v = latch;
            assign reg_if.cnt_pkt_long_lower_nxt_v = latch;
            assign {reg_if.cnt_pkt_long_upper_nxt, reg_if.cnt_pkt_long_lower_nxt} = pkt_cnt;
            assign reg_if.cnt_byte_long_upper_nxt_v = latch;
            assign reg_if.cnt_byte_long_lower_nxt_v = latch;
            assign {reg_if.cnt_byte_long_upper_nxt, reg_if.cnt_byte_long_lower_nxt} = byte_cnt;
        end : g__long
        // Don't count long packets
        else begin : g__long_ignored
            assign reg_if.cnt_pkt_long_upper_nxt_v = 1'b1;
            assign reg_if.cnt_pkt_long_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_pkt_long_upper_nxt, reg_if.cnt_pkt_long_lower_nxt} = 64'h0;
            assign reg_if.cnt_byte_long_upper_nxt_v = 1'b1;
            assign reg_if.cnt_byte_long_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_byte_long_upper_nxt, reg_if.cnt_byte_long_lower_nxt} = 64'h0;
        end : g__long_ignored
 
        // Count other packets
        if (COUNT_OTHER) begin : g__other
            // Counters
            logic [PKT_CNT_WID-1:0]  pkt_cnt;
            logic [BYTE_CNT_WID-1:0] byte_cnt;
            // Update logic
            initial begin
                pkt_cnt = '0;
                byte_cnt = '0;
            end
            always @(posedge clk) begin
                if (clear) begin
                    pkt_cnt <= '0;
                    byte_cnt <= '0;
                end
                if (evt && count_sel == STATUS_UNDEFINED) begin
                    pkt_cnt <= pkt_cnt + 1;
                    byte_cnt <= byte_cnt + size;
                end
            end
            // Register assignment
            assign reg_if.cnt_pkt_other_upper_nxt_v = latch;
            assign reg_if.cnt_pkt_other_lower_nxt_v = latch;
            assign {reg_if.cnt_pkt_other_upper_nxt, reg_if.cnt_pkt_other_lower_nxt} = pkt_cnt;
            assign reg_if.cnt_byte_other_upper_nxt_v = latch;
            assign reg_if.cnt_byte_other_lower_nxt_v = latch;
            assign {reg_if.cnt_byte_other_upper_nxt, reg_if.cnt_byte_other_lower_nxt} = byte_cnt;
        end : g__other
        // Don't count other packets
        else begin : g__other_ignored
            assign reg_if.cnt_pkt_other_upper_nxt_v = 1'b1;
            assign reg_if.cnt_pkt_other_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_pkt_other_upper_nxt, reg_if.cnt_pkt_other_lower_nxt} = 64'h0;
            assign reg_if.cnt_byte_other_upper_nxt_v = 1'b1;
            assign reg_if.cnt_byte_other_lower_nxt_v = 1'b1;
            assign {reg_if.cnt_byte_other_upper_nxt, reg_if.cnt_byte_other_lower_nxt} = 64'h0;
        end : g__other_ignored
    endgenerate

endmodule : packet_counters

