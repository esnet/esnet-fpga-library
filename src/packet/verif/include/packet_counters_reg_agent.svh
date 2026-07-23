class packet_counters_reg_agent extends packet_counters_reg_blk_agent;

    //===================================
    // Properties
    //===================================
    local static const string __CLASS_NAME = "packet_verif_pkg::packet_counters_reg_agent";

    //===================================
    // Methods
    //===================================
    function new(
            input string name = "packet_counters_reg_agent",
            reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET = 0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
    endfunction

    // Clear all internal counts (write control with clear=CLEAR_ON_WR_EVT).
    task clear();
        packet_counters_reg_pkg::reg_control_t ctrl;
        ctrl.latch = packet_counters_reg_pkg::CONTROL_LATCH_LATCH_ON_CLK;
        ctrl.clear = packet_counters_reg_pkg::CONTROL_CLEAR_CLEAR_ON_WR_EVT;
        this.write_control(ctrl);
    endtask

    // Good packets / bytes
    task get_pkt_ok_count(output longint unsigned count);
        packet_counters_reg_pkg::reg_cnt_pkt_ok_upper_t upper;
        packet_counters_reg_pkg::reg_cnt_pkt_ok_lower_t lower;
        this.read_cnt_pkt_ok_upper(upper);
        this.read_cnt_pkt_ok_lower(lower);
        count = {upper, lower};
    endtask

    task get_byte_ok_count(output longint unsigned count);
        packet_counters_reg_pkg::reg_cnt_byte_ok_upper_t upper;
        packet_counters_reg_pkg::reg_cnt_byte_ok_lower_t lower;
        this.read_cnt_byte_ok_upper(upper);
        this.read_cnt_byte_ok_lower(lower);
        count = {upper, lower};
    endtask

    // Errored packets / bytes
    task get_pkt_err_count(output longint unsigned count);
        packet_counters_reg_pkg::reg_cnt_pkt_err_upper_t upper;
        packet_counters_reg_pkg::reg_cnt_pkt_err_lower_t lower;
        this.read_cnt_pkt_err_upper(upper);
        this.read_cnt_pkt_err_lower(lower);
        count = {upper, lower};
    endtask

    task get_byte_err_count(output longint unsigned count);
        packet_counters_reg_pkg::reg_cnt_byte_err_upper_t upper;
        packet_counters_reg_pkg::reg_cnt_byte_err_lower_t lower;
        this.read_cnt_byte_err_upper(upper);
        this.read_cnt_byte_err_lower(lower);
        count = {upper, lower};
    endtask

    // Overflow packets / bytes
    task get_pkt_oflow_count(output longint unsigned count);
        packet_counters_reg_pkg::reg_cnt_pkt_oflow_upper_t upper;
        packet_counters_reg_pkg::reg_cnt_pkt_oflow_lower_t lower;
        this.read_cnt_pkt_oflow_upper(upper);
        this.read_cnt_pkt_oflow_lower(lower);
        count = {upper, lower};
    endtask

    task get_byte_oflow_count(output longint unsigned count);
        packet_counters_reg_pkg::reg_cnt_byte_oflow_upper_t upper;
        packet_counters_reg_pkg::reg_cnt_byte_oflow_lower_t lower;
        this.read_cnt_byte_oflow_upper(upper);
        this.read_cnt_byte_oflow_lower(lower);
        count = {upper, lower};
    endtask

    // Short packets / bytes
    task get_pkt_short_count(output longint unsigned count);
        packet_counters_reg_pkg::reg_cnt_pkt_short_upper_t upper;
        packet_counters_reg_pkg::reg_cnt_pkt_short_lower_t lower;
        this.read_cnt_pkt_short_upper(upper);
        this.read_cnt_pkt_short_lower(lower);
        count = {upper, lower};
    endtask

    task get_byte_short_count(output longint unsigned count);
        packet_counters_reg_pkg::reg_cnt_byte_short_upper_t upper;
        packet_counters_reg_pkg::reg_cnt_byte_short_lower_t lower;
        this.read_cnt_byte_short_upper(upper);
        this.read_cnt_byte_short_lower(lower);
        count = {upper, lower};
    endtask

    // Long packets / bytes
    task get_pkt_long_count(output longint unsigned count);
        packet_counters_reg_pkg::reg_cnt_pkt_long_upper_t upper;
        packet_counters_reg_pkg::reg_cnt_pkt_long_lower_t lower;
        this.read_cnt_pkt_long_upper(upper);
        this.read_cnt_pkt_long_lower(lower);
        count = {upper, lower};
    endtask

    task get_byte_long_count(output longint unsigned count);
        packet_counters_reg_pkg::reg_cnt_byte_long_upper_t upper;
        packet_counters_reg_pkg::reg_cnt_byte_long_lower_t lower;
        this.read_cnt_byte_long_upper(upper);
        this.read_cnt_byte_long_lower(lower);
        count = {upper, lower};
    endtask

endclass : packet_counters_reg_agent
