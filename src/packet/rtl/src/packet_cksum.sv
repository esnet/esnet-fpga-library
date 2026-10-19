// Module: packet_cksum
//
// Description: Computes the 16-bit one's complement (IP-style) checksum
//              over a packet data stream. The output `cksum` is valid
//              combinatorially on the EOP beat. A value of 0x0000 is
//              remapped to 0xffff, reserving 0 for "not calculated"
//              (TCP/UDP convention).
//
//              The caller is responsible for:
//               - gating `vld` with any backpressure signal
//               - asserting `reset` at the start of each new packet
//
module packet_cksum #(
    parameter int DATA_BYTE_WID = 8   // must match packet_intf DATA_BYTE_WID
) (
    input  logic                              clk,
    input  logic                              srst,

    // Synchronous reset — assert for one cycle at start of each packet
    input  logic                              reset,

    // Data stream — vld must already incorporate any rdy gating
    input  logic                              vld,
    input  logic [0:DATA_BYTE_WID-1][7:0]     data,
    input  logic                              eop,
    input  logic [$clog2(DATA_BYTE_WID)-1:0]  mty,

    // 16-bit result — valid combinatorially on the EOP beat
    output logic [15:0]                       cksum
);
    logic [31:0] acc;
    logic [31:0] beat;

    always_comb begin : comb_beat
        beat = '0;
        for (int i = 0; i < DATA_BYTE_WID; i += 2) begin
            automatic logic [7:0] hi = data[i];
            automatic logic [7:0] lo = (i + 1 < DATA_BYTE_WID) ? data[i+1] : 8'h00;
            if (eop) begin
                automatic int valid = DATA_BYTE_WID - int'(mty);
                if (i >= valid)          beat = beat;
                else if (i + 1 >= valid) beat += {hi, 8'h00};
                else                     beat += {hi, lo};
            end else begin
                beat += {hi, lo};
            end
        end
    end

    always_ff @(posedge clk) begin
        if (srst || reset)          acc <= '0;
        else if (vld && eop)        acc <= '0;       // clear after EOP for next packet
        else if (vld)               acc <= acc + beat;
    end

    always_comb begin : comb_cksum
        automatic logic [31:0] folded = acc;
        if (vld) folded = folded + beat;
        folded = (folded[31:16] + folded[15:0]);
        folded = (folded[31:16] + folded[15:0]);
        cksum = ~folded[15:0];
        if (cksum == 16'h0000) cksum = 16'hffff;
    end

endmodule : packet_cksum
