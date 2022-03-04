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
module crc32_x64 (
    input  logic clk,
    input  logic srst,
    input  logic en,
    input  logic [0:63][7:0] data,
    output logic [31:0] crc
);
    import crc_pkg::*;

    logic             _en;
    logic [0:63][7:0] _data;
    logic [31:0]      _crc;

    crc #(
        .CONFIG (crc_pkg::CRC32.cfg),
        .DATA_BYTES (64)
    ) i_crc (
        .clk  (clk),
        .srst (srst),
        .en   (_en),
        .data (_data),
        .crc  (_crc)
    );

    initial begin
        _en = 1'b0;
        _data = 0;
    end
    always @(posedge clk) begin
        _en <= en;
        _data <= data;
    end

    initial crc = 1'b0;
    always @(posedge clk) crc <= _crc;

endmodule : crc32_x64
