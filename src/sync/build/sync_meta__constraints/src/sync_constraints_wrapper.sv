module sync_constraints_wrapper (
    input logic clk_in, clk_out, rst_in, rst_out,
    input logic [7:0] sig_in,
    output logic [7:0] sig_out
);
    sync_meta #(.DATA_WID(8)) i_sync_meta (.*);

    // The source is compiled, but this reference is absent after elaboration.
    if (0) begin : g_unused
        logic unused_reset;
        sync_areset i_sync_areset (
            .clk_out(clk_out), .rst_in(rst_in), .rst_out(unused_reset)
        );
    end
endmodule
