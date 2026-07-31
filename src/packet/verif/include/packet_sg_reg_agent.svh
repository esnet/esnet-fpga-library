class packet_sg_reg_agent extends reg_verif_pkg::reg_blk_agent;

    //===================================
    // Properties
    //===================================
    local static const string __CLASS_NAME = "packet_verif_pkg::packet_sg_reg_agent";

    // Address offsets matching packet_sg_core_decoder address map
    local static const int ALLOC_OFFSET        = 'h0000;
    local static const int INPUT_CNT_0_OFFSET  = 'h0100;
    local static const int OUTPUT_CNT_0_OFFSET = 'h0500;
    local static const int CNT_REGION_SIZE     = 'h0100;

    alloc_reg_agent                 alloc_agent;
    local packet_counters_reg_agent __input_cnt_agent  [4];
    local packet_counters_reg_agent __output_cnt_agent [4];

    local int __num_input_ifs;
    local int __num_output_ifs;

    //===================================
    // Methods
    //===================================
    function new(
            input string name = "packet_sg_reg_agent",
            reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET    = 0,
            input int NUM_INPUT_IFS  = 1,
            input int NUM_OUTPUT_IFS = 1
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent   = reg_agent;
        __num_input_ifs  = NUM_INPUT_IFS;
        __num_output_ifs = NUM_OUTPUT_IFS;

        alloc_agent = new("alloc_agent", reg_agent, BASE_OFFSET + ALLOC_OFFSET);

        for (int g = 0; g < 4; g++) begin
            __input_cnt_agent[g] = new(
                $sformatf("input_cnt_agent[%0d]", g),
                reg_agent,
                BASE_OFFSET + INPUT_CNT_0_OFFSET + g * CNT_REGION_SIZE
            );
            __output_cnt_agent[g] = new(
                $sformatf("output_cnt_agent[%0d]", g),
                reg_agent,
                BASE_OFFSET + OUTPUT_CNT_0_OFFSET + g * CNT_REGION_SIZE
            );
        end
    endfunction

    // Clear all input and output counters
    task clear();
        for (int g = 0; g < __num_input_ifs;  g++) __input_cnt_agent[g].clear();
        for (int g = 0; g < __num_output_ifs; g++) __output_cnt_agent[g].clear();
    endtask

    // Clear all input/output counters for the given interface
    task clear_input(input int input_if);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].clear();
    endtask

    task clear_output(input int output_if);
        __check_output_if(output_if);
        __output_cnt_agent[output_if].clear();
    endtask

    // Input counter accessors
    task get_input_pkt_ok_count(input int input_if, output longint unsigned count);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].get_pkt_ok_count(count);
    endtask

    task get_input_byte_ok_count(input int input_if, output longint unsigned count);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].get_byte_ok_count(count);
    endtask

    task get_input_pkt_err_count(input int input_if, output longint unsigned count);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].get_pkt_err_count(count);
    endtask

    task get_input_byte_err_count(input int input_if, output longint unsigned count);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].get_byte_err_count(count);
    endtask

    task get_input_pkt_oflow_count(input int input_if, output longint unsigned count);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].get_pkt_oflow_count(count);
    endtask

    task get_input_byte_oflow_count(input int input_if, output longint unsigned count);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].get_byte_oflow_count(count);
    endtask

    task get_input_pkt_short_count(input int input_if, output longint unsigned count);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].get_pkt_short_count(count);
    endtask

    task get_input_byte_short_count(input int input_if, output longint unsigned count);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].get_byte_short_count(count);
    endtask

    task get_input_pkt_long_count(input int input_if, output longint unsigned count);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].get_pkt_long_count(count);
    endtask

    task get_input_byte_long_count(input int input_if, output longint unsigned count);
        __check_input_if(input_if);
        __input_cnt_agent[input_if].get_byte_long_count(count);
    endtask

    // Output counter accessors (only OK and ERR are reachable from packet_gather)
    task get_output_pkt_ok_count(input int output_if, output longint unsigned count);
        __check_output_if(output_if);
        __output_cnt_agent[output_if].get_pkt_ok_count(count);
    endtask

    task get_output_byte_ok_count(input int output_if, output longint unsigned count);
        __check_output_if(output_if);
        __output_cnt_agent[output_if].get_byte_ok_count(count);
    endtask

    task get_output_pkt_err_count(input int output_if, output longint unsigned count);
        __check_output_if(output_if);
        __output_cnt_agent[output_if].get_pkt_err_count(count);
    endtask

    task get_output_byte_err_count(input int output_if, output longint unsigned count);
        __check_output_if(output_if);
        __output_cnt_agent[output_if].get_byte_err_count(count);
    endtask

    //===================================
    // Local helpers
    //===================================
    local function void __check_input_if(input int input_if);
        if (input_if < 0 || input_if >= __num_input_ifs)
            $fatal(0, "%s: input_if %0d out of range [0:%0d)", __CLASS_NAME, input_if, __num_input_ifs);
    endfunction

    local function void __check_output_if(input int output_if);
        if (output_if < 0 || output_if >= __num_output_ifs)
            $fatal(0, "%s: output_if %0d out of range [0:%0d)", __CLASS_NAME, output_if, __num_output_ifs);
    endfunction

endclass : packet_sg_reg_agent
