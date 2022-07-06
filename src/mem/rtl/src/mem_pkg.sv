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

package mem_pkg;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum {
        RAM_STYLE_AUTO,
        RAM_STYLE_BLOCK,
        RAM_STYLE_DISTRIBUTED,
        RAM_STYLE_REGISTER,
        RAM_STYLE_REGISTERS,
        RAM_STYLE_MIXED,
        RAM_STYLE_ULTRA
    } xilinx_ram_style_t;

    typedef enum {
        STD,
        FWFT
    } mem_rd_mode_t;

    // -----------------------------
    // Functions
    // -----------------------------
    function automatic xilinx_ram_style_t get_default_ram_style_sync(input int DEPTH, input int WIDTH);
        if (DEPTH <= 256)                return RAM_STYLE_DISTRIBUTED;
        else if (DEPTH <= 512)           return RAM_STYLE_BLOCK;
        else if (WIDTH <= 16)            return RAM_STYLE_BLOCK;
        else if (DEPTH * WIDTH <= 65536) return RAM_STYLE_BLOCK;
        else                             return RAM_STYLE_ULTRA;
    endfunction
    
    function automatic xilinx_ram_style_t get_default_ram_style_async(input int DEPTH, input int WIDTH);
        if (DEPTH <= 256) return RAM_STYLE_DISTRIBUTED;
        else              return RAM_STYLE_BLOCK;
    endfunction

    function automatic xilinx_ram_style_t get_default_ram_style(input int DEPTH, input int WIDTH, input bit ASYNC=0);
        if (ASYNC) return get_default_ram_style_async(DEPTH, WIDTH);
        else       return get_default_ram_style_sync(DEPTH, WIDTH);
    endfunction

    // Calculate additional (write) pipelining added to accommodate array of specified size
    function automatic int get_default_wr_pipeline_stages(input xilinx_ram_style_t ram_style);
        case (ram_style)
            RAM_STYLE_ULTRA : return 1;
            default         : return 0;
        endcase
    endfunction

    // Calculate additional (read) pipelining added to accommodate array of specified depth
    function automatic int get_default_rd_pipeline_stages(input xilinx_ram_style_t ram_style);
        case (ram_style)
            RAM_STYLE_DISTRIBUTED : return 0;
            RAM_STYLE_BLOCK       : return 1;
            default               : return 2;
        endcase
    endfunction

    // Calculate overall memory read latency given number of pipeline stages
    function automatic int __get_rd_latency(input int RD_PIPELINE_STAGES);
        return RD_PIPELINE_STAGES + 1;
    endfunction

    // Calculate overall memory read latency given specified read pipeline
    function automatic int get_default_rd_latency(input int DEPTH, input int WIDTH, input bit ASYNC=0);
        return __get_rd_latency(get_default_rd_pipeline_stages(get_default_ram_style(DEPTH, WIDTH, ASYNC)));
    endfunction

endpackage : mem_pkg
