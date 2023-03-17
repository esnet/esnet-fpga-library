package mem_map_pkg;

    // -----------------------------
    // Functions
    // -----------------------------
    localparam int MAX_REGIONS = 32;

    typedef struct packed {
        int base;
        int size;
    } region_spec_t;

    localparam region_spec_t DEFAULT_REGION_SPEC = '{base: 0, size: 0};

    typedef struct {
        int NUM_REGIONS;
        region_spec_t region [MAX_REGIONS];
    } map_spec_t;

    localparam map_spec_t DEFAULT_MAP_SPEC = '{
        NUM_REGIONS: 1,
        region: '{
            default: DEFAULT_REGION_SPEC
        }
    };

    // -----------------------------
    // Functions
    // -----------------------------
    function bit is_addr_in_region(input int addr, input region_spec_t region);
        automatic int ADDR_LO = region.base;
        automatic int ADDR_HI = region.base + region.size;
        return (addr inside {[ADDR_LO:ADDR_HI]});
    endfunction

    function void decode (
            input int addr,
            input map_spec_t mem_map,
            output int region,
            output int offset,
            output bit error
        );
        error = 1'b1;
        region = 0;
        offset = 0;
        for (int i = 0; i < mem_map.NUM_REGIONS; i++) begin
            if (is_addr_in_region(addr, mem_map.region[i])) begin
                region = i;
                error = 1'b0;
                offset = addr - mem_map.region[i].base;
            end
        end
    endfunction

endpackage : mem_map_pkg
