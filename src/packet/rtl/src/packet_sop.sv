// Tracks packet SOP state
module packet_sop (
    input  logic clk,
    input  logic srst,
    input  logic vld,
    input  logic rdy,
    input  logic eop,
    output logic sop
);
    initial sop = 1'b1;
    always @(posedge clk) begin
        if (srst) sop <= 1'b1;
        else begin
            if (vld && rdy && eop) sop <= 1'b1;
            else if (vld && rdy)   sop <= 1'b0;
        end
    end

endmodule : packet_sop
