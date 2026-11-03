// =========================================================================
// crc_accum
//
// Accumulating parallel CRC — extends crc.sv with per-packet state feedback
// and support for partial beats (mty > 0).
//
// Unlike crc.sv (which always starts from CONFIG.INIT), crc_accum maintains
// an internal state register across beats and resets it to CONFIG.INIT on
// srst.  The output is combinatorial (not registered), so it reflects the
// accumulated CRC through the current beat's data and is valid on the same
// clock cycle as the asserted en beat.
//
// mty:
//   mty gives the number of trailing bytes in the beat that carry no payload
//   (0 = all bytes valid) and must be in [0, DATA_BYTES-1] — a beat with 0
//   valid bytes isn't a real transfer and isn't supported (don't assert en
//   for one).  The module masks the unused data bytes and adjusts the state
//   shift so that only the (DATA_BYTES - mty) valid bytes contribute to the
//   CRC.
//
// Typical use:
//   - Drive en from (valid && ready).
//   - Set mty=0 on full beats; set mty to the empty-byte count on the EOP beat.
//   - Assert srst one cycle after the EOP beat to reset state for the next packet.
//   - Sample crc on the EOP beat to obtain the full-packet CRC.
//
// Implementation:
//   The full-width state shift is a GF(2) matrix-vector multiply over
//   DATA_BYTES basis vectors precomputed at elaboration time.  Partial beats
//   need a shift of (DATA_BYTES - mty) bytes instead; a table of basis
//   vector sets is precomputed for every valid byte count 1…DATA_BYTES and
//   selected at runtime via a MUX on valid_bytes.  Synthesis constant-folds
//   all basis vector computations to XOR trees, leaving only the MUX and
//   conditional XOR logic in the mapped netlist.
// =========================================================================
module crc_accum
    import crc_pkg::*;
#(
    parameter crc_config_t CONFIG = DEFAULT_CRC,
    parameter int DATA_BYTES = 1
)(
    input  logic clk,
    input  logic srst,
    input  logic en,
    // Empty bytes at end of this beat.  0 = all bytes valid.  Valid range is
    // [0, DATA_BYTES-1] (a beat with 0 valid bytes isn't a real transfer).
    input  logic [(DATA_BYTES > 1 ? $clog2(DATA_BYTES) : 1)-1:0] mty,
    input  logic [0:DATA_BYTES-1][7:0] data,
    output logic [CONFIG.WIDTH-1:0] crc,
    // Asserts (combinatorially) when the accumulated CRC register equals
    // CONFIG.RESIDUE — i.e. a complete message + appended FCS was received
    // without error.  Sample on the EOP beat.
    output logic check
);
    localparam int CRC_WIDTH = CONFIG.WIDTH;

    // Precomputed basis vector for state bit i shifted by n_bytes.
    // Synthesis constant-folds each call to a fixed XOR tree (no runtime logic).
    function automatic CRC_T shift_basis_n(int state_bit, int n_bytes);
        return crc_shift(CONFIG, CRC_T'(1) << state_bit, n_bytes * 8);
    endfunction

    // Raw CRC state (before REFOUT/XOROUT).  Resets to CONFIG.INIT.
    logic [CRC_WIDTH-1:0] state_reg;

    // Right-align valid bytes: the independent CRC functions assign exponent 0
    // to data[DATA_BYTES-1], so the last valid byte must land there.  Shift
    // right by mty; zero-fill the vacated leading positions (zeros contribute
    // nothing to the CRC regardless of exponent).
    // Loop bound is the constant DATA_BYTES so synthesis can unroll it.
    logic [0:DATA_BYTES-1][7:0] data_masked;
    always_comb begin
        if (mty != 0) begin
            for (int j = 0; j < DATA_BYTES; j++)
                data_masked[j] = (j >= int'(mty)) ? data[j - int'(mty)] : 8'h00;
        end else begin
            data_masked = data;
        end
    end

    // Data contribution — same computation as crc.sv, applied to data_masked.
    logic [CRC_WIDTH-1:0] crc_data;
    generate
        if (DATA_BYTES > 4) begin : g_wide
            localparam int DATA_DWORDS = DATA_BYTES % 4 == 0 ? DATA_BYTES / 4 : DATA_BYTES / 4 + 1;
            logic [0:DATA_DWORDS-1][0:3][7:0] data_dwords;
            logic [CRC_WIDTH-1:0] crc_dword [DATA_DWORDS];
            assign data_dwords = data_masked;
            always_comb begin
                for (int i = 0; i < DATA_DWORDS; i++)
                    crc_dword[i] = calculate_dwordwise_independent(CONFIG, data_dwords[i], (DATA_DWORDS-1)-i);
            end
            always_comb begin
                crc_data = 0;
                for (int i = 0; i < DATA_DWORDS; i++)
                    crc_data ^= crc_dword[i];
            end
        end : g_wide
        else begin : g_narrow
            logic [CRC_WIDTH-1:0] crc_byte [DATA_BYTES];
            always_comb begin
                for (int i = 0; i < DATA_BYTES; i++)
                    crc_byte[i] = calculate_bytewise_independent(CONFIG, data_masked[i], (DATA_BYTES-1)-i);
            end
            always_comb begin
                crc_data = 0;
                for (int i = 0; i < DATA_BYTES; i++)
                    crc_data ^= crc_byte[i];
            end
        end : g_narrow
    endgenerate

    // Shift state by (valid_bytes * 8) bits via a precomputed basis-vector
    // table (one entry per valid byte count 1…DATA_BYTES).  mty==DATA_BYTES
    // (zero valid bytes) is unsupported; caller must not assert en for it.
    logic [$clog2(DATA_BYTES+1)-1:0] valid_bytes;
    assign valid_bytes = DATA_BYTES - mty;

    logic [CRC_WIDTH-1:0] crc_from_state_table [DATA_BYTES];
    always_comb begin
        for (int n = 0; n < DATA_BYTES; n++) begin  // n+1 valid bytes
            crc_from_state_table[n] = '0;
            for (int i = 0; i < CRC_WIDTH; i++) begin
                if (state_reg[i])
                    crc_from_state_table[n] ^= shift_basis_n(i, n + 1);
            end
        end
    end

    // New raw state for this beat
    logic [CRC_WIDTH-1:0] crc_int;
    assign crc_int = crc_from_state_table[valid_bytes - 1] ^ crc_data;

    // State register — initialized to CONFIG.INIT by the first srst pulse.
    always_ff @(posedge clk) begin
        if (srst)    state_reg <= CONFIG.INIT;
        else if (en) state_reg <= crc_int;
    end

    // Combinatorial output — REFOUT reflection then XOROUT, from crc_int
    logic [CRC_WIDTH-1:0] crc_pre_xor;
    generate
        if (CONFIG.REFOUT) begin : g_refout
            assign crc_pre_xor = {<<{crc_int}};
        end : g_refout
        else begin : g_no_refout
            assign crc_pre_xor = crc_int;
        end : g_no_refout
    endgenerate
    assign crc = crc_pre_xor ^ CONFIG.XOROUT;

    assign check = (crc_pre_xor == CONFIG.RESIDUE[CONFIG.WIDTH-1:0]);

endmodule : crc_accum
