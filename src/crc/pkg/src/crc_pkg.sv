package crc_pkg;

    // ========================================================
    // (Global) Parameters
    // ========================================================
    localparam string CHECK_STRING = "123456789";
    localparam int CHECK_STRING_CHARS = 9;

    // ========================================================
    // Typedefs
    // ========================================================
    typedef logic [31:0] CRC_T;

    // Packed struct so Verilator can constant-fold it as a module parameter.
    // All fields are 32 bits wide (total 256 bits).
    typedef struct packed {
        logic [31:0] WIDTH;
        logic [31:0] POLY;
        logic [31:0] INIT;
        logic [31:0] REFIN;
        logic [31:0] REFOUT;
        logic [31:0] XOROUT;
        logic [31:0] CHECK;
        logic [31:0] RESIDUE;
    } crc_config_t;

    // ========================================================
    // Functions
    // ========================================================
    function automatic CRC_T calculate_bitwise(input crc_config_t _config, input CRC_T crc_in, input bit data);
        if (crc_in[_config.WIDTH-1] ^ data) return (crc_in << 1) ^ _config.POLY;
        else                                return (crc_in << 1);
    endfunction

    function automatic CRC_T calculate_bytewise(input crc_config_t _config, input CRC_T crc_in, input bit[7:0] data);
        automatic CRC_T crc_bit [8];
        automatic CRC_T crc_data;
        automatic CRC_T crc_init;

        automatic logic[7:0] data_refin;

        // Reflect input bytes where specified
        if (_config.REFIN) data_refin = {<<{data}};
        else               data_refin = data;

        // Calculate CRC from single bit slice at specified bit offset
        for (int i = 0; i < 8; i++) begin
            crc_bit[i] = calculate_bitwise_independent(_config, data_refin[i], i);
        end
        // Calculate aggregate CRC due to all data bits
        crc_data = 0;
        for (int i = 0; i < 8; i++) begin
            crc_data ^= crc_bit[i];
        end

        // Calculate CRC from input CRC (equivalent to data = 8'h00)
        crc_init = crc_shift(_config, crc_in, 8);

        // CRC over byte is XOR of these constituent CRC calculations
        return (crc_data ^ crc_init);
    endfunction

    function automatic CRC_T calculate_dwordwise(input crc_config_t _config, input CRC_T crc_in, input bit[0:3][7:0] data);
        automatic CRC_T crc_byte [4];
        automatic CRC_T crc_data;
        automatic CRC_T crc_init;

        // Calculate CRC from single byte slice at specified byte offset
        for (int i = 0; i < 4; i++) begin
            crc_byte[i] = calculate_bytewise_independent(_config, data[i], 3-i);
        end
        // Calculate aggregate CRC due to all data bytes
        crc_data = 0;
        for (int i = 0; i < 4; i++) begin
            crc_data ^= crc_byte[i];
        end

        // Calculate CRC from input CRC (equivalent to data = 32'h00000000)
        crc_init = crc_shift(_config, crc_in, 32);

        // CRC over dword is XOR of these constituent CRC calculations
        return (crc_data ^ crc_init);
    endfunction

    function automatic CRC_T crc_shift(input crc_config_t _config, input CRC_T crc_in, input int shift_bits);
        automatic CRC_T crc_shifted = crc_in;
        for (int i = 0; i < shift_bits; i++) begin
            crc_shifted = calculate_bitwise(_config, crc_shifted, 1'b0);
        end
        return crc_shifted;
    endfunction

    function automatic CRC_T calculate_bitwise_independent(input crc_config_t _config, input bit data, input int shift_bits);
        CRC_T crc = calculate_bitwise(_config, 0, data);
        return crc_shift(_config, crc, shift_bits);
    endfunction

    function automatic CRC_T calculate_bytewise_independent(input crc_config_t _config, input bit[7:0] data, input int shift_bytes);
        CRC_T crc = calculate_bytewise(_config, 0, data);
        return crc_shift(_config, crc, shift_bytes * 8);
    endfunction

    function automatic CRC_T calculate_dwordwise_independent(input crc_config_t _config, input bit[31:0] data, input int shift_dwords);
        CRC_T crc = calculate_dwordwise(_config, 0, data);
        return crc_shift(_config, crc, shift_dwords * 32);
    endfunction

    function automatic string print_crc_config(input crc_config_t _config);
        string _config_str = "";
        _config_str = {$sformatf("CRC%0d", _config.WIDTH), "\n"};
        _config_str = {_config_str, $sformatf("POLY:   %8x", _config.POLY), "\n"};
        _config_str = {_config_str, $sformatf("INIT:   %8x", _config.INIT), "\n"};
        _config_str = {_config_str, $sformatf("REFIN:  %08b", _config.REFIN), "\n"};
        _config_str = {_config_str, $sformatf("REFOUT: %08b", _config.REFOUT), "\n"};
        _config_str = {_config_str, $sformatf("XOROUT: %8x", _config.XOROUT), "\n"};
        return _config_str;
    endfunction

    // ========================================================
    // CRC Specification Library
    // - See "Catalogue of parameterised CRC algorithms" at:
    //   https://reveng.sourceforge.io/crc-catalogue/all.htm
    // ========================================================
    // ------------------
    // CRC-8
    // ------------------
    localparam crc_config_t CRC8_SMBUS  = '{WIDTH: 8,  POLY: 32'h07,       INIT: 32'h00,       REFIN: 0, REFOUT: 0, XOROUT: 32'h00,       CHECK: 32'hf4,       RESIDUE: 32'h00};
    // -- Aliases
    localparam crc_config_t CRC8        = CRC8_SMBUS;

    // ------------------
    // CRC-16
    // ------------------
    localparam crc_config_t CRC16_CDMA2000 = '{WIDTH: 16, POLY: 32'hc867, INIT: 32'hffff, REFIN: 0, REFOUT: 0, XOROUT: 32'h0000, CHECK: 32'h4c06, RESIDUE: 32'h0000};
    localparam crc_config_t CRC16_KERMIT   = '{WIDTH: 16, POLY: 32'h1021, INIT: 32'h0000, REFIN: 1, REFOUT: 1, XOROUT: 32'h0000, CHECK: 32'h2189, RESIDUE: 32'h0000};
    // -- Aliases
    localparam crc_config_t CRC16_CCITT    = CRC16_KERMIT;
    localparam crc_config_t CRC16_V41_LSB  = CRC16_KERMIT;
    localparam crc_config_t CRC16_USB      = '{WIDTH: 16, POLY: 32'h8005, INIT: 32'hffff, REFIN: 1, REFOUT: 1, XOROUT: 32'hffff, CHECK: 32'hb4c8, RESIDUE: 32'hb001};
    localparam crc_config_t CRC16_XMODEM   = '{WIDTH: 16, POLY: 32'h1021, INIT: 32'h0000, REFIN: 0, REFOUT: 0, XOROUT: 32'h0000, CHECK: 32'h31c3, RESIDUE: 32'h0000};
    // -- Aliases
    localparam crc_config_t CRC16_LTE      = CRC16_XMODEM;
    localparam crc_config_t CRC16_V41_MSB  = CRC16_XMODEM;

    // ------------------
    // CRC-24
    // ------------------
    localparam crc_config_t CRC24_INTERLAKEN = '{WIDTH: 24, POLY: 32'h328b63, INIT: 32'hffffff, REFIN: 0, REFOUT: 0, XOROUT: 32'hffffff, CHECK: 32'hb4f3e6, RESIDUE: 32'h144e63};

    // ------------------
    // CRC-32
    // ------------------
    localparam crc_config_t CRC32_BZIP2    = '{WIDTH: 32, POLY: 32'h04c11db7, INIT: 32'hffffffff, REFIN: 0, REFOUT: 0, XOROUT: 32'hffffffff, CHECK: 32'hfc891918, RESIDUE: 32'hc704dd7b};
    // -- Aliases
    localparam crc_config_t CRC32_AAL5     = CRC32_BZIP2;
    localparam crc_config_t CRC32_CKSUM    = '{WIDTH: 32, POLY: 32'h04c11db7, INIT: 32'h00000000, REFIN: 0, REFOUT: 0, XOROUT: 32'hffffffff, CHECK: 32'h765e7680, RESIDUE: 32'hc704dd7b};
    // -- Aliases
    localparam crc_config_t CRC32_POSIX    = CRC32_CKSUM;
    localparam crc_config_t CRC32_ISO_HDLC = '{WIDTH: 32, POLY: 32'h04c11db7, INIT: 32'hffffffff, REFIN: 1, REFOUT: 1, XOROUT: 32'hffffffff, CHECK: 32'hcbf43926, RESIDUE: 32'hdebb20e3};
    // -- Aliases
    localparam crc_config_t CRC32          = CRC32_ISO_HDLC;
    localparam crc_config_t CRC32_V42      = CRC32_ISO_HDLC;
    localparam crc_config_t CRC32_ISCSI    = '{WIDTH: 32, POLY: 32'h1edc6f41, INIT: 32'hffffffff, REFIN: 1, REFOUT: 1, XOROUT: 32'hffffffff, CHECK: 32'he3069283, RESIDUE: 32'hb798b438};
    // -- Aliases
    localparam crc_config_t CRC32_INTERLAKEN = CRC32_ISCSI;
    localparam crc_config_t CRC32_C          = CRC32_ISCSI;
    localparam crc_config_t CRC32_AIXM      = '{WIDTH: 32, POLY: 32'h814141ab, INIT: 32'h00000000, REFIN: 0, REFOUT: 0, XOROUT: 32'h00000000, CHECK: 32'h3010bf7f, RESIDUE: 32'h00000000};
    localparam crc_config_t CRC32_Q         = CRC32_AIXM;
    localparam crc_config_t CRC32_BASE91_D  = '{WIDTH: 32, POLY: 32'ha833982b, INIT: 32'hffffffff, REFIN: 1, REFOUT: 1, XOROUT: 32'hffffffff, CHECK: 32'h87315576, RESIDUE: 32'h45270551};
    localparam crc_config_t CRC32_D         = CRC32_BASE91_D;
    localparam crc_config_t CRC32_AUTOSAR   = '{WIDTH: 32, POLY: 32'hf4acfb13, INIT: 32'hffffffff, REFIN: 1, REFOUT: 1, XOROUT: 32'hffffffff, CHECK: 32'h1697d06a, RESIDUE: 32'h904cddbf};

    // ------------------
    // Default
    // ------------------
    localparam crc_config_t DEFAULT_CRC = CRC32;

endpackage : crc_pkg
