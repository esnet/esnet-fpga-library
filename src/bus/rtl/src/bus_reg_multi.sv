// (Bidirectional) bus multi-register pipelining stage
// Registers both the forward signals (valid + data)
// and the reverse signals (ready)
// NOTE: For STAGES > 0, valid/ready handshaking protocol
//       will be violated and must be accommodated by e.g.
//       bookending with bus_pipe_tx and bus_pipe_rx modules
module bus_reg_multi #(
    parameter int STAGES = 1,
    parameter bit IGNORE_READY = 1'b0
) (
    bus_intf.rx   bus_if_from_tx,
    bus_intf.tx   bus_if_to_rx
);
    localparam int  DATA_WID = $bits(bus_if_from_tx.DATA_T);
    localparam type DATA_T = logic[DATA_WID-1:0];

    generate
        if (STAGES > 1) begin : g__multi_stage
            (* DONT_TOUCH *) logic  srst_p  [STAGES];
            (* DONT_TOUCH *) logic  valid_p [STAGES];
            (* DONT_TOUCH *) DATA_T data_p  [STAGES];

            initial valid_p = '{default: 1'b0};
            always @(posedge bus_if_from_tx.clk) begin
                for (int i = 1; i < STAGES; i++) begin
                    srst_p [i] <= srst_p [i-1];
                    valid_p[i] <= valid_p[i-1];
                    data_p [i] <= data_p [i-1];
                end
                srst_p [0] <= bus_if_from_tx.srst;
                valid_p[0] <= bus_if_from_tx.valid;
                data_p [0] <= bus_if_from_tx.data;
            end
            assign bus_if_to_rx.srst  = srst_p [STAGES-1];
            assign bus_if_to_rx.valid = valid_p[STAGES-1];
            assign bus_if_to_rx.data  = data_p [STAGES-1];
            
            if (IGNORE_READY) begin : g__ignore_ready
                assign bus_if_from_tx.ready = 1'b1;
            end : g__ignore_ready
            else begin : g__obey_ready
                (* DONT_TOUCH *) logic ready_p [STAGES];
                initial ready_p = '{default: 1'b0};
                always @(posedge bus_if_from_tx.clk) begin
                    for (int i = 1; i < STAGES; i++) begin
                        ready_p[i] <= ready_p[i-1];
                    end
                    ready_p[0] <= bus_if_to_rx.ready;
                end
                assign bus_if_from_tx.ready = ready_p[STAGES-1];
            end : g__obey_ready
        end : g__multi_stage
        else if (STAGES == 1) begin : g__single_stage
            bus_reg #(IGNORE_READY) i_bus_reg (.*);
        end : g__single_stage
        else begin : g__zero_stage
            bus_intf_connector i_bus_intf_connector (.*);
        end : g__zero_stage
    endgenerate

endmodule : bus_reg_multi
