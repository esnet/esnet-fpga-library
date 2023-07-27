package crc_pkg;

    // ========================================================
    // (Global) Parameters
    // ========================================================
    localparam string CHECK_STRING = "123456789";
    localparam int CHECK_STRING_CHARS = 9;

    // ========================================================
    // Typedefs
    // ========================================================
    typedef bit[31:0] CRC_T;

    typedef struct {
        int   WIDTH;
        CRC_T POLY;
        CRC_T INIT;
        int   REFIN;
        int   REFOUT;
        CRC_T XOROUT;
        CRC_T CHECK;
        CRC_T RESIDUE;
    } crc_config_t;

    typedef struct {
        string       name;
        string       shortname;
        crc_config_t cfg;
    } crc_spec_t;

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
    localparam crc_config_t CRC8_SMBUS_CFG = '{WIDTH: 8, POLY: 8'h07, INIT: 8'h00, REFIN: 0, REFOUT: 0, XOROUT: 8'h00, CHECK: 8'hf4, RESIDUE: 8'h00};
    localparam crc_spec_t   CRC8_SMBUS     = '{name: "CRC-8/SMBUS", shortname: "crc8_smbus",  cfg: CRC8_SMBUS_CFG};
    // -- Aliases
    localparam crc_spec_t   CRC8           = '{name: "CRC-8",       shortname: "crc8",        cfg: CRC8_SMBUS_CFG};

    // ------------------
    // CRC-16
    // ------------------
    // CRC-16/CDMA2000
    localparam crc_config_t CRC16_CDMA2000_CFG = '{WIDTH: 16, POLY: 16'hc867, INIT: 16'hffff, REFIN: 0, REFOUT: 0, XOROUT: 16'h0000, CHECK: 16'h4c06, RESIDUE: 16'h0000};
    localparam crc_spec_t   CRC16_CDMA2000     = '{name: "CRC-16/CDMA2000",    shortname: "crc16_cdma2000",    cfg: CRC16_CDMA2000_CFG};

    // CRC-16/KERMIT
    localparam crc_config_t CRC16_KERMIT_CFG   = '{WIDTH: 16, POLY: 16'h1021, INIT: 16'h0000, REFIN: 1, REFOUT: 1, XOROUT: 16'h0000, CHECK: 16'h2189, RESIDUE: 16'h0000};
    localparam crc_spec_t   CRC16_KERMIT       = '{name: "CRC-16/KERMIT",      shortname: "crc16_kermit",      cfg: CRC16_KERMIT_CFG};
    // -- Aliases
    localparam crc_spec_t   CRC16_CCITT        = '{name: "CRC-16/CCITT",       shortname: "crc16_ccitt",       cfg: CRC16_KERMIT_CFG};
    localparam crc_spec_t   CRC16_V41_LSB      = '{name: "CRC-16/V-41-LSB",    shortname: "crc16_v41_lsb",     cfg: CRC16_KERMIT_CFG};

    // CRC-16/USB
    localparam crc_config_t CRC16_USB_CFG      = '{WIDTH: 16, POLY: 16'h8005, INIT: 16'hffff, REFIN: 1, REFOUT: 1, XOROUT: 16'hffff, CHECK: 16'hb4c8, RESIDUE: 16'hb001};
    localparam crc_spec_t   CRC16_USB          = '{name: "CRC-16/USB",         shortname: "crc16_usb",         cfg: CRC16_USB_CFG};

    // CRC-16/XMODEM
    localparam crc_config_t CRC16_XMODEM_CFG   = '{WIDTH: 16, POLY: 16'h1021, INIT: 16'h0000, REFIN: 0, REFOUT: 0, XOROUT: 16'h0000, CHECK: 16'h31c3, RESIDUE: 16'h0000};
    localparam crc_spec_t   CRC16_XMODEM       = '{name: "CRC-16/XMODEM",      shortname: "crc16_xmodem",      cfg: CRC16_XMODEM_CFG};
    // -- Aliases
    localparam crc_spec_t   CRC16_LTE          = '{name: "CRC-16/LTE",         shortname: "crc16_lte",         cfg: CRC16_XMODEM_CFG};
    localparam crc_spec_t   CRC16_V41_MSB      = '{name: "CRC-16/V-41-MSB",    shortname: "crc16_v41_msb",     cfg: CRC16_XMODEM_CFG};

    // ------------------
    // CRC-24
    // ------------------
    // CRC-24/INTERLAKEN
    localparam crc_config_t CRC24_INTERLAKEN_CFG = '{WIDTH: 24, POLY: 24'h328b63, INIT: 24'hffffff, REFIN: 0, REFOUT: 0, XOROUT: 24'hffffff, CHECK: 24'hb4f3e6, RESIDUE: 24'h144e63};
    localparam crc_spec_t   CRC24_INTERLAKEN     = '{name: "CRC-24/INTERLAKEN", shortname: "crc24_interlaken", cfg: CRC24_INTERLAKEN_CFG};

    // ------------------
    // CRC-32
    // ------------------
    // CRC-32/BZIP2
    localparam crc_config_t CRC32_BZIP2_CFG    = '{WIDTH: 32, POLY: 32'h04c11db7, INIT: 32'hffffffff, REFIN: 0, REFOUT: 0, XOROUT: 32'hffffffff, CHECK: 32'hfc891918, RESIDUE: 32'hc704dd7b};
    localparam crc_spec_t   CRC32_BZIP2        = '{name: "CRC-32/BZIP-2",      shortname: "crc32_bzip2",       cfg: CRC32_BZIP2_CFG};
    // -- Aliases
    localparam crc_spec_t   CRC32_AAL5         = '{name: "CRC-32/AAL5",        shortname: "crc32_aal5",        cfg: CRC32_BZIP2_CFG};

    // CRC-32/CKSUM
    localparam crc_config_t CRC32_CKSUM_CFG    = '{WIDTH: 32, POLY: 32'h04c11db7, INIT: 32'h00000000, REFIN: 0, REFOUT: 0, XOROUT: 32'hffffffff, CHECK: 32'h765e7680, RESIDUE: 32'hc704dd7b};
    localparam crc_spec_t   CRC32_CKSUM        = '{name: "CRC-32/CKSUM",       shortname: "crc32_cksum",       cfg: CRC32_CKSUM_CFG};
    // -- Aliases
    localparam crc_spec_t   CRC32_POSIX        = '{name: "CRC-32/POSIX",       shortname: "crc32_posix",       cfg: CRC32_CKSUM_CFG};

    // CRC-32/ISO-HDLC
    localparam crc_config_t CRC32_ISO_HDLC_CFG = '{WIDTH: 32, POLY: 32'h04c11db7, INIT: 32'hffffffff, REFIN: 1, REFOUT: 1, XOROUT: 32'hffffffff, CHECK: 32'hcbf43926, RESIDUE: 32'hdebb20e3};
    localparam crc_spec_t   CRC32_ISO_HDLC     = '{name: "CRC-32/ISO-HDLC",    shortname: "crc32_iso_hdlc",    cfg: CRC32_ISO_HDLC_CFG};
    // -- Aliases
    localparam crc_spec_t   CRC32              = '{name: "CRC-32",             shortname: "crc32",             cfg: CRC32_ISO_HDLC_CFG};
    localparam crc_spec_t   CRC32_V42          = '{name: "CRC-32/V-42",        shortname: "crc32_v42",         cfg: CRC32_ISO_HDLC_CFG};

    // CRC-32/ICSCI
    localparam crc_config_t CRC32_ISCSI_CFG    = '{WIDTH: 32, POLY: 32'h1edc6f41, INIT: 32'hffffffff, REFIN: 1, REFOUT: 1, XOROUT: 32'hffffffff, CHECK: 32'he3069283, RESIDUE: 32'hb798b438};
    localparam crc_spec_t   CRC32_ISCSI        = '{name: "CRC-32/ISCSI",       shortname: "crc32_iscsi",       cfg: CRC32_ISCSI_CFG};
    // -- Aliases
    localparam crc_spec_t   CRC32_INTERLAKEN   = '{name: "CRC-32/INTERLAKEN",  shortname: "crc32_interlaken",  cfg: CRC32_ISCSI_CFG};
    localparam crc_spec_t   CRC32_C            = '{name: "CRC-32C",            shortname: "crc32c",            cfg: CRC32_ISCSI_CFG};

    // CRC-32/AIXM
    localparam crc_config_t CRC32_AIXM_CFG     = '{WIDTH: 32, POLY: 32'h814141ab, INIT: 32'h00000000, REFIN: 0, REFOUT: 0, XOROUT: 32'h00000000, CHECK: 32'h3010bf7f, RESIDUE: 32'h00000000};
    localparam crc_spec_t   CRC32_AIXM         = '{name: "CRC-32/AIXM",        shortname: "crc32_aixm",        cfg: CRC32_AIXM_CFG};
    localparam crc_spec_t   CRC32_Q            = '{name: "CRC-32Q",            shortname: "crc32q",            cfg: CRC32_AIXM_CFG};

    // CRC-32/BASE91-D
    localparam crc_config_t CRC32_BASE91_D_CFG = '{WIDTH: 32, POLY: 32'ha833982b, INIT: 32'hffffffff, REFIN: 1, REFOUT: 1, XOROUT: 32'hffffffff, CHECK: 32'h87315576, RESIDUE: 32'h45270551};
    localparam crc_spec_t   CRC32_BASE91_D     = '{name: "CRC-32/BASE91-D",    shortname: "crc32_base91_d",    cfg: CRC32_BASE91_D_CFG};
    localparam crc_spec_t   CRC32_D            = '{name: "CRC-32D",            shortname: "crc32d",            cfg: CRC32_BASE91_D_CFG};

    // CRC-32/AUTOSAR
    localparam crc_config_t CRC32_AUTOSAR_CFG  = '{WIDTH: 32, POLY: 32'hf4acfb13, INIT: 32'hffffffff, REFIN: 1, REFOUT: 1, XOROUT: 32'hffffffff, CHECK: 32'h1697d06a, RESIDUE: 32'h904cddbf};
    localparam crc_spec_t   CRC32_AUTOSAR      = '{name: "CRC-32/AUTOSAR",     shortname: "crc32_autosar",     cfg: CRC32_AUTOSAR_CFG};

    // ------------------
    // Default
    // ------------------
    localparam crc_spec_t DEFAULT_CRC = CRC32;

endpackage : crc_pkg
