class packet_q_core_reg_agent extends packet_sg_reg_agent;

    //===================================
    // Properties
    //===================================
    local static const string __CLASS_NAME = "packet_verif_pkg::packet_q_core_reg_agent";

    //===================================
    // Methods
    //===================================
    function new(
            input string name = "packet_q_core_reg_agent",
            reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET    = 0,
            input int NUM_INPUT_IFS  = 1,
            input int NUM_OUTPUT_IFS = 1
    );
        super.new(name, reg_agent, BASE_OFFSET, NUM_INPUT_IFS, NUM_OUTPUT_IFS);
    endfunction

endclass : packet_q_core_reg_agent
