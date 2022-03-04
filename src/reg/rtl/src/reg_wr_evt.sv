// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

module reg_wr_evt #(
    parameter type T = bit[31:0],
    parameter T INIT_VALUE = 0,
    parameter int WR_DATA_BYTES = 4
)(
    input  logic                          clk,
    input  logic                          srst,
    input  logic                          wr,
    input  logic                          wr_en,
    input  logic [WR_DATA_BYTES-1:0][7:0] wr_data,
    input  logic [WR_DATA_BYTES-1:0]      wr_byte_en,
    output T                              rd_data,
    output logic                          wr_evt
);

    // Implement underlying register as read/write
    reg_rw #(.T(T), .INIT_VALUE(INIT_VALUE), .WR_DATA_BYTES(WR_DATA_BYTES)) _reg_rw (.*);

    // Synthesize write event strobe
    logic _evt = 1'b0;
    always_ff @(posedge clk) begin
        if (srst) _evt <= 1'b0;
        else begin
            if (wr && wr_en) _evt <= 1'b1;
            else             _evt <= 1'b0;
        end
    end
    assign wr_evt = _evt;

endmodule : reg_wr_evt
