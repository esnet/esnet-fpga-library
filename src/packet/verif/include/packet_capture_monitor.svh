class packet_capture_monitor #(parameter type META_T=bit) extends packet_monitor#(META_T);

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_capture_monitor";

    packet_capture_reg_blk_agent control_agent;
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
    function new(input string name="packet_capture_monitor",
                 input int mem_size=16384,
                 input int data_wid,
                 const ref reg_verif_pkg::reg_agent reg_agent,
                 input int BASE_OFFSET=0
        );
        super.new(name);
        this.set_reset_timeout(2*mem_size);
        this.set_op_timeout(128);
        control_agent = new("packet_capture_reg_blk_agent", 'h0);
        control_agent.reg_agent = reg_agent;
        mem_agent = new("packet_mem_agent", mem_size, data_wid, reg_agent, 'h400);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    virtual function automatic void set_debug_level(input int DEBUG_LEVEL);
        super.set_debug_level(DEBUG_LEVEL);
        control_agent.set_debug_level(DEBUG_LEVEL);
        mem_agent.set_debug_level(DEBUG_LEVEL);
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
    function automatic void _reset();
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
    task _wait(input int cycles);
        control_agent._wait(cycles);
    endtask

    task enable();
        packet_capture_reg_pkg::reg_control_t reg_control;
        control_agent.read_control(reg_control);
        reg_control.enable = 1'b1;
        control_agent.write_control(reg_control);
    endtask

    task _disable();
        packet_capture_reg_pkg::reg_control_t reg_control;
        control_agent.read_control(reg_control);
        reg_control.enable = 1'b0;
        control_agent.write_control(reg_control);
    endtask

    // Wait for interface to be ready to accept transactions
    // [[ implements std_verif_pkg::monitor.wait_ready() ]]
    task wait_ready();
        packet_capture_reg_pkg::reg_status_t reg_status;
        trace_msg("--- wait_ready() ---");
        do
            control_agent.read_status(reg_status);
        while (reg_status.code != packet_capture_reg_pkg::STATUS_CODE_READY);
        mem_agent.wait_ready();
        trace_msg("--- wait_ready() Done. ---");
    endtask

    // Generic transaction (no timeout protection)
    task _transact(
            input packet_capture_reg_pkg::fld_command_code_t _command,
            output bit                                       _error
        );
        // Signals
        packet_capture_reg_pkg::reg_status_t status;
        packet_capture_reg_pkg::reg_command_t command;

        trace_msg("_transact()");

        // Acquire lock
        control_agent.lock();

        // Clear status register
        control_agent.read_status(status);

        // Issue command
        command.code = _command;
        control_agent.write_command(_command);

        // Poll status until done/error/timeout reported
        do
            control_agent.read_status(status);
        while ((status.done == 1'b0) && (status.error == 1'b0));

        _error = status.error;

        // Return lock
        control_agent.unlock();

        trace_msg("_transact() Done.");
    endtask

    // Generic transaction (+ timeout protection)
    task transact(
            input packet_capture_reg_pkg::fld_command_code_t _command,
            output bit                                       _error,
            output bit                                       _timeout,
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
        transact(packet_capture_reg_pkg::COMMAND_CODE_NOP, error, timeout, get_op_timeout());
        trace_msg("nop() Done.");
    endtask

    task capture(output packet#(META_T) packet, output bit _error, output bit _timeout, input int TIMEOUT=0 );
        automatic byte __data[];
        automatic bit capture_error, capture_timeout;
        automatic bit read_error, read_timeout;
        automatic int size;
        automatic META_T meta;
        automatic bit err;
        trace_msg("capture()");
        // Issue transaction
        transact(packet_capture_reg_pkg::COMMAND_CODE_CAPTURE, capture_error, capture_timeout, TIMEOUT);
        // Get size of captured packets
        __get_captured_bytes(size);
        // Get metadata
        __get_meta(meta);
        // Read packet data
        mem_agent.read(0, size, __data, read_error, read_timeout);
        // Syntesize packet result
        packet = packet_raw#(META_T)::create_from_bytes("captured_pkt", __data, meta, err);
        _error = capture_error | read_error;
        _timeout = capture_timeout | read_timeout;
        trace_msg("capture() Done.");
    endtask

    // Receive packet as raw byte array
    // [[ implements packet_verif_pkg::packet_monitor.receive_raw ]]
    task receive_raw(output byte data[], output META_T meta, output bit err);
        packet#(META_T) packet;
        automatic bit error, timeout;
        automatic int mem_window_size;
        automatic int size;
        trace_msg("receive_raw()");
        // Issue transaction
        capture(packet, error, timeout, 0);
        data = packet.to_bytes();
        meta = packet.get_meta();
        err = packet.is_errored();
        trace_msg("receive_raw() Done.");
    endtask

    local task __get_captured_bytes(output int captured_bytes);
        packet_capture_reg_pkg::reg_status_t reg_status;
        control_agent.read_status(reg_status);
        captured_bytes = reg_status.packet_bytes;
    endtask

    local task __get_meta(output META_T _meta);
        automatic int byte_idx;
        bit [0:META_BYTES-1][7:0] meta_bytes;
        bit [3:0][7:0] meta_reg;
        trace_msg("__get_meta()");
        for (int i = 0; i < META_REGS; i++) begin
            control_agent.read_meta(i, meta_reg);
            for (int j = 0; j < 4; j++) begin
                byte_idx = i * 4 + j;
                if (byte_idx < META_BYTES) meta_bytes[byte_idx] = meta_reg[j];
            end
        end
        _meta = meta_bytes;
        trace_msg($sformatf("__get_meta() Done. (meta=0x%0x)", _meta));
    endtask

    // Get packet memory size (read block parameterization value)
    task read_mem_size(output int _size);
        packet_capture_reg_pkg::reg_info_t reg_info;
        trace_msg("read_mem_size()");
        control_agent.read_info(reg_info);
        _size = reg_info.mem_size;
        trace_msg($sformatf("read_mem_size() Done. Got: %0d.", _size));
    endtask
    
    // Get packet metadata width (read block parameterization value)
    task read_meta_width(output int _meta_width);
        packet_capture_reg_pkg::reg_info_t reg_info;
        control_agent.read_info(reg_info);
        _meta_width = reg_info.meta_width;
    endtask

endclass: packet_capture_monitor
