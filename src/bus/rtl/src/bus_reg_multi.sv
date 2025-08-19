// (Bidirectional) bus multi-register pipelining stage
// Registers both the forward signals (valid + data)
// and the reverse signals (ready)
// NOTE: For STAGES > 0, valid/ready handshaking protocol
//       will be violated and must be accommodated by e.g.
//       bookending with bus_pipe_tx and bus_pipe_rx modules
module bus_reg_multi #(
    parameter int  STAGES = 1
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int DATA_WID = from_tx.DATA_WID;
    
    // Parameter checking
    bus_intf_parameter_check param_check (.*);
    initial begin
        std_pkg::param_check_gt(STAGES, 0, "STAGES");
    end

    // Clock
    logic clk;
    assign clk = from_tx.clk;

    generate
        if (STAGES > 0) begin : g__multi_stage
            (* shreg_extract = "no" *) logic                valid_p [STAGES];
            (* streg_extract = "no" *) logic [DATA_WID-1:0] data_p  [STAGES];
            (* shreg_extract = "no" *) logic                ready_p [STAGES];

            initial valid_p = '{default: 1'b0};
            always @(posedge clk) begin
                if (from_tx.srst) valid_p = '{default: 1'b0};
                else begin
                    for (int i = 1; i < STAGES; i++) begin
                        valid_p[i] <= valid_p[i-1];
                    end
                    valid_p[0] <= from_tx.valid;
                end
            end

            always_ff @(posedge clk) begin
                for (int i = 1; i < STAGES; i++) begin
                    data_p [i] <= data_p [i-1];
                end
                data_p [0] <= from_tx.data;
            end

            assign to_rx.valid = valid_p[STAGES-1];
            assign to_rx.data  = data_p [STAGES-1];
            
            initial ready_p = '{default: 1'b0};
            always @(posedge clk) begin
                for (int i = 1; i < STAGES; i++) begin
                    ready_p[i] <= ready_p[i-1];
                end
                ready_p[0] <= to_rx.ready;
            end
            assign from_tx.ready = ready_p[STAGES-1];

        end : g__multi_stage
        else begin : g__zero_stage
            bus_intf_connector i_bus_intf_connector (.*);
        end : g__zero_stage
    endgenerate

endmodule : bus_reg_multi
