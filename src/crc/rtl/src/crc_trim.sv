// =========================================================================
// crc_trim
//
// Removes the effect of trailing zero-padded bytes from a fully-formatted
// CRC value (REFOUT/XOROUT already applied), recovering the CRC as if those
// bytes had never been part of the message.
//
// Intended use: a producer accumulates a CRC (e.g. via crc_accum) treating
// every beat as fully valid, with any genuinely empty trailing bytes forced
// to zero before they reach the accumulator. crc_trim is then applied,
// combinationally or pipelined, to undo the contribution of those `mty`
// zero bytes and recover the true CRC of the valid message bytes.
//
// This is purely a function of (CONFIG, crc_in, mty) — no raw data or
// accumulator state is required.
// =========================================================================
module crc_trim
    import crc_pkg::*;
#(
    parameter crc_config_t CONFIG = DEFAULT_CRC,
    parameter int DATA_BYTES = 1
)(
    input  logic [CONFIG.WIDTH-1:0] crc_in,
    // Number of trailing zero-padded bytes to remove, in [0, DATA_BYTES-1].
    input  logic [(DATA_BYTES > 1 ? $clog2(DATA_BYTES) : 1)-1:0] mty,
    output logic [CONFIG.WIDTH-1:0] crc,
    // Asserts when the corrected CRC equals CONFIG.RESIDUE — i.e. a complete
    // message + appended FCS was received without error.
    output logic check
);

    // remove_trailing_zero_bytes' internal shift loop trip count must be an
    // elaboration-time constant for synthesis to unroll it, but mty is a
    // runtime port.  As crc_accum does for its own state-shift table, build
    // one entry per possible mty value (0..DATA_BYTES-1) over a
    // constant-bound loop — so n is constant within each unrolled call — and
    // select the live entry with a runtime mux.
    logic [CONFIG.WIDTH-1:0] crc_trim_table [DATA_BYTES];
    always_comb begin
        for (int n = 0; n < DATA_BYTES; n++)
            crc_trim_table[n] = remove_trailing_zero_bytes(CONFIG, crc_in, n);
    end

    logic [CONFIG.WIDTH-1:0] crc_corrected;
    assign crc_corrected = crc_trim_table[mty];

    assign crc = crc_corrected;
    // RESIDUE is defined pre-XOROUT (see crc_accum.crc_pre_xor); undo XOROUT
    // (self-inverse) before comparing.
    assign check = ((crc_corrected ^ CONFIG.XOROUT[CONFIG.WIDTH-1:0]) == CONFIG.RESIDUE[CONFIG.WIDTH-1:0]);

endmodule : crc_trim
