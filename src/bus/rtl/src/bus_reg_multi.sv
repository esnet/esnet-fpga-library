// (Bidirectional) bus multi-register pipelining stage
// Registers both the forward signals (valid + data)
// and the reverse signals (ready)
// NOTE: For STAGES > 0, valid/ready handshaking protocol
//       will be violated and must be accommodated by e.g.
//       bookending with bus_pipe_tx and bus_pipe_rx modules
module bus_reg_multi #(
    parameter type DATA_T = logic,
    parameter int  STAGES = 1
) (
    bus_intf.rx   bus_if_from_tx,
    bus_intf.tx   bus_if_to_rx
);
    // Parameter checking
    initial begin
        std_pkg::param_check($bits(bus_if_from_tx.DATA_T), $bits(DATA_T), "bus_if_from_tx.DATA_T");
        std_pkg::param_check($bits(bus_if_to_rx.DATA_T),   $bits(DATA_T), "bus_if_to_rx.DATA_T");
        std_pkg::param_check_gt(STAGES, 0, "STAGES");
    end

    generate
        if (STAGES > 0) begin : g__multi_stage
            (* shreg_extract = "no" *) logic  srst_p  [STAGES];
            (* shreg_extract = "no" *) logic  valid_p [STAGES];
            (* streg_extract = "no" *) DATA_T data_p  [STAGES];
            (* shreg_extract = "no" *) logic  ready_p [STAGES];

            initial begin
                srst_p = '{default: 1'b1};
                valid_p = '{default: 1'b0};
            end
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
            
            initial ready_p = '{default: 1'b0};
            always @(posedge bus_if_from_tx.clk) begin
                for (int i = 1; i < STAGES; i++) begin
                    ready_p[i] <= ready_p[i-1];
                end
                ready_p[0] <= bus_if_to_rx.ready;
            end
            assign bus_if_from_tx.ready = ready_p[STAGES-1];

        end : g__multi_stage
        else begin : g__zero_stage
            bus_intf_connector #(.DATA_T(DATA_T)) i_bus_intf_connector (.*);
        end : g__zero_stage
    endgenerate

endmodule : bus_reg_multi
