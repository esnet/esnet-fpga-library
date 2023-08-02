package mem_pkg;

    // -----------------------------
    // Typedefs
    // -----------------------------

    typedef enum {
        OPT_MODE_DEFAULT, // Balanced
        OPT_MODE_TIMING,  // Optimize for performance (more pipelining)
        OPT_MODE_LATENCY  // Optimize for latency     (less pipelining)
    } opt_mode_t;

    typedef struct {
        int ADDR_WID;
        int DATA_WID;
        bit ASYNC;
        bit RESET_FSM;
        opt_mode_t OPT_MODE;
    } spec_t;

    localparam spec_t DEFAULT_MEM_SPEC = '{
        ADDR_WID: 8,
        DATA_WID: 32,
        ASYNC: 0,
        RESET_FSM: 0,
        OPT_MODE: OPT_MODE_DEFAULT
    };

    // -----------------------------
    // Functions
    // -----------------------------
    // Convert optization mode to Xilinx RAM library type
    function automatic xilinx_ram_pkg::opt_mode_t translate_opt_mode(input opt_mode_t mem_opt_mode);
        case (mem_opt_mode)
            OPT_MODE_DEFAULT,
            OPT_MODE_TIMING  : return xilinx_ram_pkg::OPT_MODE_TIMING;
            OPT_MODE_LATENCY : return xilinx_ram_pkg::OPT_MODE_LATENCY;
        endcase
    endfunction

    // Calculate RAM write latency given specified memory configuration
    function automatic int get_ram_wr_latency(input spec_t SPEC);
        return xilinx_ram_pkg::get_wr_latency(SPEC.ADDR_WID, SPEC.DATA_WID, SPEC.ASYNC, translate_opt_mode(SPEC.OPT_MODE));
    endfunction

    // Calculate RAM read latency given specified memory configuration
    function automatic int get_ram_rd_latency(input spec_t SPEC);
        return xilinx_ram_pkg::get_rd_latency(SPEC.ADDR_WID, SPEC.DATA_WID, SPEC.ASYNC, translate_opt_mode(SPEC.OPT_MODE));
    endfunction

    // Calculate overall memory write latency given specified memory configuration
    function automatic int get_wr_latency(input spec_t SPEC);
        if (SPEC.RESET_FSM) begin
            case (SPEC.OPT_MODE)
                OPT_MODE_TIMING : return get_ram_wr_latency(SPEC) + 1;
                default         : return get_ram_wr_latency(SPEC);
            endcase
        end else return get_ram_wr_latency(SPEC);
    endfunction

    // Calculate overall memory read latency given specified memory configuration
    function automatic int get_rd_latency(input spec_t SPEC);
        if (SPEC.RESET_FSM) begin
            case (SPEC.OPT_MODE)
                OPT_MODE_TIMING : return get_ram_rd_latency(SPEC) + 1;
                default         : return get_ram_rd_latency(SPEC);
            endcase
        end else return get_ram_rd_latency(SPEC);
    endfunction

endpackage : mem_pkg
