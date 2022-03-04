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
module crc
    import crc_pkg::*;
#(
    parameter crc_config_t CONFIG = DEFAULT_CRC.cfg,
    parameter int DATA_BYTES = 1
)(
    // Clock/reset
    input  logic clk,
    input  logic srst,
    // Control
    input  logic en,
    // Input
    input  logic [0:DATA_BYTES-1][7:0] data,
    // Output
    output logic [CONFIG.WIDTH-1:0] crc
);

    // Parameters
    localparam int CRC_WIDTH = CONFIG.WIDTH;

    // Signals
    logic [CRC_WIDTH-1:0] crc_init;
    logic [CRC_WIDTH-1:0] crc_data;
    logic [CRC_WIDTH-1:0] crc_int;
    logic [CRC_WIDTH-1:0] crc_pre_xor;
    logic [CRC_WIDTH-1:0] crc_post_xor;

    // Calculate CRC due to input CRC only (equivalent to calculating CRC for data = '0)
    always_comb crc_init = crc_shift(CONFIG, CONFIG.INIT, DATA_BYTES*8);

    // Calculate CRC due to data
    generate
        if (DATA_BYTES > 4) begin : g__wide_crc
            localparam int DATA_DWORDS = DATA_BYTES % 4 == 0 ? DATA_BYTES / 4 : DATA_BYTES / 4 + 1;
            logic [0:DATA_DWORDS-1][0:3][7:0] data_dwords;
            logic [CRC_WIDTH-1:0] crc_dword [DATA_DWORDS];
            logic [CRC_WIDTH-1:0] crc_dword_p [DATA_DWORDS];
            // Data as DWORDs
            assign data_dwords = data;
            // Calculate 'independent' CRC for each 32-bit segment (adjusted for position within overall data word)
            always_comb begin
                for (int i = 0; i < DATA_DWORDS; i++) begin
                    crc_dword[i] = calculate_dwordwise_independent(CONFIG, data_dwords[i], (DATA_DWORDS-1)-i);
                end
            end
            // Combine 'independent' CRCs
            always_comb begin
                crc_data = 0;
                for (int i = 0; i < DATA_DWORDS; i++) begin
                    crc_data ^= crc_dword[i];
                end
            end
        end : g__wide_crc
        else begin : g__narrow_crc
            logic [CRC_WIDTH-1:0] crc_byte [DATA_BYTES];
            logic [CRC_WIDTH-1:0] crc_byte_p [DATA_BYTES];
            always_comb begin
                for (int i = 0; i < DATA_BYTES; i++) begin
                    crc_byte[i] = calculate_bytewise_independent(CONFIG, data[i], (DATA_BYTES-1)-i);
                end
            end
            // Combine 'independent' CRCs
            always_comb begin
                crc_data = 0;
                for (int i = 0; i < DATA_BYTES; i++) begin
                    crc_data ^= crc_byte[i];
                end
            end
        end : g__narrow_crc
    endgenerate

    // Intermediate CRC value
    assign crc_int = crc_init ^ crc_data;

    // Reflect CRC value at output, where specified by implementation
    generate
        if (CONFIG.REFOUT) begin : g__refout
            assign crc_pre_xor = {<<{crc_int}};
        end : g__refout
        else begin : g__no_refout
            assign crc_pre_xor = crc_int;
        end : g__no_refout
    endgenerate

    // Implementation-specific output XOR
    assign crc_post_xor = crc_pre_xor ^ CONFIG.XOROUT;

    initial crc = 0;
    always @(posedge clk) begin
        if (srst) crc <= 0;
        else if (en) crc <= crc_post_xor;
    end

endmodule : crc
