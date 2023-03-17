module crc_serial
    import crc_pkg::*;
#(
    parameter crc_config_t CONFIG = DEFAULT_CRC.cfg
)(
    // Clock/reset
    input  logic clk,
    input  logic srst,
    // Control
    input  logic en,
    // Input
    input  logic data,
    // Output
    output logic [CONFIG.WIDTH-1:0] crc,
    // Status
    output logic check
);

    // Signals
    logic [CONFIG.WIDTH-1:0] crc_reg;
    logic [CONFIG.WIDTH-1:0] crc_pre_xor;

    // Maintain CRC state
    initial crc_reg = CONFIG.INIT;
    always @(posedge clk) begin
        if (srst) crc_reg <= CONFIG.INIT;
        else begin
            if (en) crc_reg <= calculate_bitwise(CONFIG, crc_reg, data);
        end
    end

    // Reflect CRC value at output, where specified by implementation
    generate
        if (CONFIG.REFOUT) begin : g__refout
            assign crc_pre_xor = {<<{crc_reg}};
        end : g__refout
        else begin : g__no_refout
            assign crc_pre_xor = crc_reg;
        end : g__no_refout
    endgenerate

    // Implementation-specific output XOR
    assign crc = crc_pre_xor ^ CONFIG.XOROUT;

    // Assert check output when CRC equals implementation-specific 'residue' value
    // Note: CRC(message + CRC(message)) = residue, for any message
    assign check = (crc_pre_xor == CONFIG.RESIDUE);

endmodule : crc_serial
