package xilinx_ram_pkg;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum {
        RAM_STYLE_BLOCK,
        RAM_STYLE_DISTRIBUTED,
        RAM_STYLE_ULTRA
    } ram_style_t;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum {
        OPT_MODE_TIMING,
        OPT_MODE_LATENCY
    } opt_mode_t;

    // ------------------------------------------------------------------------
    // "Internal" Functions
    //
    // - these functions deal with vendor/technology-specific parameters and
    //   are therefore intended to be useful internally within this
    //   (Xilinx RAM) library.
    // ------------------------------------------------------------------------
    // Determine (synchronous) RAM technology based on memory parameters
    function automatic ram_style_t get_default_ram_style_sync(input int ADDR_WID, input int DATA_WID, input opt_mode_t OPT_MODE=OPT_MODE_TIMING);
        if (ADDR_WID <= 8)                          return RAM_STYLE_DISTRIBUTED;
        else if (ADDR_WID <= 9)                     return RAM_STYLE_BLOCK;
        else if (DATA_WID <= 16)                    return RAM_STYLE_BLOCK;
        else if ((2**ADDR_WID) * DATA_WID <= 65536) return RAM_STYLE_BLOCK;
        else if (OPT_MODE == OPT_MODE_LATENCY)      return RAM_STYLE_BLOCK;
        else                                        return RAM_STYLE_ULTRA;
    endfunction
    
    // Determine (asynchronous) RAM technology based on memory parameters
    function automatic ram_style_t get_default_ram_style_async(input int ADDR_WID, input int DATA_WID, input opt_mode_t OPT_MODE=OPT_MODE_TIMING);
        if (ADDR_WID <= 8) return RAM_STYLE_DISTRIBUTED;
        else               return RAM_STYLE_BLOCK;
    endfunction

    // Determine RAM technology based on memory parameters
    function automatic ram_style_t get_default_ram_style(input int ADDR_WID, input int DATA_WID, input bit ASYNC=0, input opt_mode_t OPT_MODE=OPT_MODE_TIMING);
        if (ASYNC) return get_default_ram_style_async(ADDR_WID, DATA_WID, OPT_MODE);
        else       return get_default_ram_style_sync(ADDR_WID, DATA_WID, OPT_MODE);
    endfunction

    // Calculate UltraRAM read pipeline stages based on size of memory array
    function automatic int get_uram_rd_pipeline_stages(input int ADDR_WID, input opt_mode_t OPT_MODE=OPT_MODE_TIMING);
        if (ADDR_WID > 15)      return 4;
        else if (ADDR_WID > 14) return 3;
        else                    return 2;
    endfunction
    
    // Calculate BlockRAM read pipeline stages based on size of memory array
    function automatic int get_bram_rd_pipeline_stages(input int ADDR_WID, input opt_mode_t OPT_MODE=OPT_MODE_TIMING);
        case (OPT_MODE)
            OPT_MODE_TIMING : return 1;
            OPT_MODE_LATENCY : return 0;
        endcase
    endfunction

    // Calculate overall memory write latency given specified memory configuration
    function automatic int _get_wr_latency(input ram_style_t ram_style, input int ADDR_WID, input opt_mode_t OPT_MODE=OPT_MODE_TIMING);
        return 1;
    endfunction

    // Calculate overall memory read latency given specified memory configuration
    function automatic int _get_rd_latency(input ram_style_t ram_style, input int ADDR_WID, input opt_mode_t OPT_MODE=OPT_MODE_TIMING);
        case (ram_style)
            RAM_STYLE_ULTRA: return 1 + get_uram_rd_pipeline_stages(ADDR_WID, OPT_MODE);
            RAM_STYLE_BLOCK: return 1 + get_bram_rd_pipeline_stages(ADDR_WID, OPT_MODE);
            RAM_STYLE_DISTRIBUTED: return 1;
        endcase
    endfunction

    // ------------------------------------------------------------------------
    // "External" Functions
    //
    // - these functions deal with generic parameters so they can be safely
    //   referenced from other libraries.
    // ------------------------------------------------------------------------
    // Calculate write latency, given (generic) memory parameters
    function automatic int get_wr_latency(input int ADDR_WID, input int DATA_WID, input bit ASYNC=1'b0, input opt_mode_t OPT_MODE=OPT_MODE_TIMING);
        ram_style_t ram_style;
        ram_style = get_default_ram_style(ADDR_WID, DATA_WID, ASYNC, OPT_MODE);
        return _get_wr_latency(ram_style, ADDR_WID, OPT_MODE);
    endfunction

    // Calculate default memory read latency, given (generic) memory parameters
    function automatic int get_rd_latency(input int ADDR_WID, input int DATA_WID, input bit ASYNC=1'b0, input opt_mode_t OPT_MODE=OPT_MODE_TIMING);
        automatic ram_style_t ram_style;
        ram_style = get_default_ram_style(ADDR_WID, DATA_WID, ASYNC, OPT_MODE);
        return _get_rd_latency(ram_style, ADDR_WID, OPT_MODE);
    endfunction

endpackage : xilinx_ram_pkg
