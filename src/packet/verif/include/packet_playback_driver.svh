class packet_playback_driver #(parameter type META_T=bit) extends packet_driver#(META_T);

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_playback_driver";

    packet_playback_reg_blk_agent control_agent;
    mem_proxy_agent mem_agent;

    //===================================
    // Parameters
    //===================================
    protected int _RESET_TIMEOUT=0;
    protected int _OP_TIMEOUT=0;

    localparam int META_BITS = $bits(META_T);
    localparam int META_BYTES = META_BITS % 8 == 0 ? META_BITS / 8 : META_BITS / 8 + 1;
    localparam int META_REGS = META_BYTES % 4 == 0 ? META_BYTES / 4 : META_BYTES / 4 + 1;

    //===================================
    // Methods
    //===================================
    function new(input string name="packet_playback_driver",
                 input int mem_size=16384,
                 input int data_wid,
                 const ref reg_verif_pkg::reg_agent reg_agent,
                 input int BASE_OFFSET=0
        );
        super.new(name);
        this.set_reset_timeout(2*mem_size);
        this.set_op_timeout(128);
        control_agent = new("packet_playback_reg_blk_agent", 'h0);
        control_agent.reg_agent = reg_agent;
        mem_agent = new("packet_mem_agent", mem_size, data_wid, reg_agent, 'h400);
    endfunction
    
    function set_debug_level(input int DEBUG_LEVEL);
        super.set_debug_level(DEBUG_LEVEL);
        control_agent.set_debug_level(DEBUG_LEVEL);
        mem_agent.set_debug_level(DEBUG_LEVEL);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set timeout (in cycles) for reset operation
    function automatic void set_reset_timeout(input int RESET_TIMEOUT);
        this._RESET_TIMEOUT = RESET_TIMEOUT;
    endfunction

    // Set timeout (in cycles) for non-reset operations
    function automatic void set_op_timeout(input int OP_TIMEOUT);
        this._OP_TIMEOUT = OP_TIMEOUT;
    endfunction

    // Get timeout (in cycles) for reset operation
    function automatic int get_reset_timeout();
        return this._RESET_TIMEOUT;
    endfunction

    // Get timeout (in cycles) for non-reset operations
    function automatic int get_op_timeout();
        return this._OP_TIMEOUT;
    endfunction

    // Reset driver state
    // [[ implements std_verif_pkg::driver._reset() ]]
    protected function automatic void _reset();
        control_agent.reset();
        mem_agent.reset();
    endfunction

    // Put (driven) packet interface in idle state
    // [[ implements std_verif_pkg::driver.idle() ]]
    task idle();
        control_agent.idle();
        mem_agent.idle();
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements std_verif_pkg::driver._wait() ]]
    protected task _wait(input int cycles);
        control_agent._wait(cycles);
    endtask

    task enable();
        packet_playback_reg_pkg::reg_control_t reg_control;
        control_agent.read_control(reg_control);
        reg_control.enable = 1'b1;
        control_agent.write_control(reg_control);
    endtask

    task _disable();
        packet_playback_reg_pkg::reg_control_t reg_control;
        control_agent.read_control(reg_control);
        reg_control.enable = 1'b0;
        control_agent.write_control(reg_control);
    endtask

    // Wait for interface to be ready to accept transactions
    // [[ implements std_verif_pkg::driver.wait_ready() ]]
    task wait_ready();
        packet_playback_reg_pkg::reg_status_t reg_status;
        trace_msg("--- wait_ready() ---");
        do
            control_agent.read_status(reg_status);
        while (reg_status.code != packet_playback_reg_pkg::STATUS_CODE_READY);
        mem_agent.wait_ready();
        trace_msg("--- wait_ready() Done. ---");
    endtask

    // Generic transaction (no timeout protection)
    task _transact(
            input packet_playback_reg_pkg::fld_command_code_t _command,
            output bit                                        _error
        );
        // Signals
        packet_playback_reg_pkg::reg_status_t status;
        packet_playback_reg_pkg::reg_command_t command;

        trace_msg("_transact()");

        // Clear status register
        trace_msg("_transact() -- Read status.");
        control_agent.read_status(status);

        // Issue command
        trace_msg("_transact() -- Issue command.");
        command.code = _command;
        control_agent.write_command(_command);

        // Poll status until done/error/timeout reported
        trace_msg("_transact() -- Poll status.");
        do
            control_agent.read_status(status);
        while ((status.done == 1'b0) && (status.error == 1'b0) && (status.timeout == 1'b0));

        _error = status.error || status.timeout;

        trace_msg("_transact() Done.");
    endtask

    // Generic transaction (+ timeout protection)
    task transact(
            input packet_playback_reg_pkg::fld_command_code_t _command,
            output bit                                        _error,
            output bit                                        _timeout,
            input  int                                        TIMEOUT=0
        );
        trace_msg($sformatf("transact(command=%s)", _command.name()));
        fork
            begin
                fork
                    begin
                        _error = 1'b0;
                        _transact(_command, _error);
                    end
                    begin
                        _timeout = 1'b0;
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            _timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        assert (_error == 0)   else info_msg($sformatf("Error detected during '%s' transaction.", _command.name));
        assert (_timeout == 0) else error_msg($sformatf("'%s' transaction timed out.", _command.name));
        trace_msg("transact() Done.");
    endtask

    // NOP (null operation; perform req/ack handshake only)
    task nop(output bit error, output bit timeout);
        trace_msg("nop()");
        transact(packet_playback_reg_pkg::COMMAND_CODE_NOP, error, timeout, get_op_timeout());
        trace_msg("nop() Done.");
    endtask

    // Send packet as raw byte array, with support for bursts
    protected task _send_raw(input byte data[], input META_T meta='0, input bit err=1'b0, input int burst=1);
        automatic bit error, timeout;
        if (data.size() < 1) begin
            debug_msg("Zero-length packet. Nothing to send.");
            return;
        end
        trace_msg("_send_raw() -- Configure.");
        // Configure transaction
        __set_config(data.size(), burst);
        __set_meta(meta);
        // Write packet data
        trace_msg("_send_raw() -- Write packet mem.");
        mem_agent.write(0, data, error, timeout);
        // Issue transaction
        trace_msg("_send_raw() -- Issue transaction.");
        if (burst > 1)
            transact(packet_playback_reg_pkg::COMMAND_CODE_SEND_BURST, error, timeout, burst*get_op_timeout());
        else
            transact(packet_playback_reg_pkg::COMMAND_CODE_SEND_ONE, error, timeout, get_op_timeout());
    endtask

    // Send single packet from raw byte array
    // [[ implements packet_verif_pkg::packet_driver.send_raw ]]
    task send_raw(input byte data[], input META_T meta='0, input bit err=1'b0);
        trace_msg("send_raw()");
        _send_raw(data, meta, err, 1);
        trace_msg("send_raw() Done.");
    endtask

    // Send a burst of the same packet
    task send_burst(input packet#(META_T) packet, input int burst=1);
        _send_raw(packet.to_bytes(), packet.get_meta(), packet.is_errored(), burst);
    endtask

    local task __set_config(input int packet_bytes, input int burst_size=1);
        packet_playback_reg_pkg::reg_config_t reg_config;
        reg_config.packet_bytes = packet_bytes;
        reg_config.burst_size = burst_size;
        control_agent.write_config(reg_config);
    endtask

    local task __set_meta(input META_T _meta);
        automatic int byte_idx;
        bit [0:META_BYTES-1][7:0] meta_bytes = _meta;
        bit [3:0][7:0] meta_reg;
        for (int i = 0; i < META_REGS; i++) begin
            for (int j = 0; j < 4; j++) begin
                byte_idx = i * 4 + j;
                if (byte_idx < META_BYTES) meta_reg[j] = meta_bytes[byte_idx];
                else                       meta_reg[j] = 0;
            end
            control_agent.write_meta(i, meta_reg);
            debug_msg($sformatf("_set_meta: Wrote 0%0x to meta reg %0d", meta_reg, i));
        end
    endtask

    // Get packet memory size (read block parameterization value)
    task read_mem_size(output int _size);
        packet_playback_reg_pkg::reg_info_t reg_info;
        control_agent.read_info(reg_info);
        _size = reg_info.mem_size;
    endtask
    
    // Get packet metadata width (read block parameterization value)
    task read_meta_width(output int _meta_width);
        packet_playback_reg_pkg::reg_info_t reg_info;
        control_agent.read_info(reg_info);
        _meta_width = reg_info.meta_width;
    endtask

endclass: packet_playback_driver
