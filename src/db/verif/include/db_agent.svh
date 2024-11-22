virtual class db_agent #(
    parameter type KEY_T = bit[7:0],
    parameter type VALUE_T = bit[31:0]
) extends std_verif_pkg::agent;

    local static const string __CLASS_NAME = "db_verif_pkg::db_agent";

    //===================================
    // Parameters
    //===================================
    local int __MAX_CAPACITY; // Maximum number of entries accommodated by the database
                              // Set __MAX_CAPACITY == 0 for no limit

    protected int _RESET_TIMEOUT=0;
    protected int _OP_TIMEOUT=0;

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Generic transaction (no timeout protection)
    pure virtual protected task _transact(input db_pkg::command_t _command, output bit _error);
    // Set key (for request)
    pure virtual protected task _set_key(input KEY_T _key);
    // Set value (for request)
    pure virtual protected task _set_value(input VALUE_T _value);
    // Read valid (from response)
    pure virtual protected task _get_valid(output bit _valid);
    // Read key (from response)
    pure virtual protected task _get_key(output KEY_T _key);
    // Read value (from response)
    pure virtual protected task _get_value(output VALUE_T _value);
    // Get database type
    pure virtual task get_type(output db_pkg::type_t _type);
    // Get database subtype
    pure virtual task get_subtype(output db_pkg::subtype_t _subtype);
    // Query database for reported size
    pure virtual task get_size(output int _size);
    // Query database for reported fill
    pure virtual task get_fill(output int _fill);
    // Wait specified number of cycles, where cycles is determined by specific instance.
    pure virtual task wait_n(input int cycles);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="db_agent", input int _max_capacity=0);
        super.new(name);
        set_max_capacity(_max_capacity);
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset agent state
    // [[ implements std_verif_pkg::agent._reset() ]]
    virtual protected function automatic void _reset();
        // Nothing to do
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

    // Set size (capacity) of database
    function automatic void set_max_capacity(input int _max_capacity);
        this.__MAX_CAPACITY = _max_capacity;
    endfunction

    // Get size (capacity) of database
    function automatic int get_max_capacity();
        return this.__MAX_CAPACITY;
    endfunction

    // Reset client
    virtual protected task _init();
        automatic bit error;
        automatic bit timeout;
        clear_all(error, timeout);
        assert (error == 0)   else error_msg("Error detected during RESET_CLIENT operation.");
        assert (timeout == 0) else error_msg("RESET_CLIENT operation timed out.");
    endtask

    // Generic transaction (+ timeout protection)
    task transact(
            input db_pkg::command_t _command,
            output bit              _error,
            output bit              _timeout,
            input  int              TIMEOUT=0
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
                            wait_n(TIMEOUT);
                            _timeout = 1'b1;
                        end else wait(0);
                    end
                join_any
                disable fork;
            end
        join
        assert (_error == 0)   else info_msg($sformatf("Error detected during '%s' transaction.", _command.name));
        assert (_timeout == 0) else error_msg($sformatf("'%s' transaction timed out.", _command.name));
        trace_msg("transact() Done.");
    endtask

    // Clear all database entries
    task clear_all(output bit error, output bit timeout);
        trace_msg("clear_all()");
        transact(db_pkg::COMMAND_CLEAR, error, timeout, this._RESET_TIMEOUT);
        trace_msg("clear_all() Done.");
    endtask

    // NOP (null operation; perform req/ack handshake only)
    task nop(output bit error, output bit timeout);
        trace_msg("nop()");
        transact(db_pkg::COMMAND_NOP, error, timeout, this._OP_TIMEOUT);
        trace_msg("nop() Done.");
    endtask

    // Install new `key:value` entry in database
    task set(
            input KEY_T key, input VALUE_T value,
            output bit error, output bit timeout
        );
        trace_msg($sformatf("set(key=0x%0x, value=0x%0x)", key, value));
        _set_key(key);
        _set_value(value);
        transact(db_pkg::COMMAND_SET, error, timeout, this._OP_TIMEOUT);
        trace_msg("set() Done.");
    endtask

    // Uninstall existing entry for `key`, if valid
    task unset(
            input KEY_T key, output bit valid, output VALUE_T value,
            output bit error, output bit timeout
        );
        trace_msg($sformatf("unset (key=0x%0x)", key));
        _set_key(key);
        transact(db_pkg::COMMAND_UNSET, error, timeout, this._OP_TIMEOUT);
        _get_valid(valid);
        _get_value(value);
        trace_msg("unset() Done.");
    endtask

    // Get value associated with `key`, if valid
    task get(
            input KEY_T key, output bit valid, output VALUE_T value,
            output bit error, output bit timeout
        );
        trace_msg($sformatf("get(key=0x%0x)", key));
        _set_key(key);
        transact(db_pkg::COMMAND_GET, error, timeout, this._OP_TIMEOUT);
        _get_valid(valid);
        _get_value(value);
        trace_msg($sformatf("get() Done. (valid=%b, value=0x%0x)", valid, value));
    endtask

    // Get value (and key) associated with 'next' entry, if valid
    task get_next(
            output bit valid, output KEY_T key, output VALUE_T value,
            output bit error, output bit timeout
        );
        trace_msg("get_next()");
        transact(db_pkg::COMMAND_GET_NEXT, error, timeout, this._OP_TIMEOUT);
        _get_valid(valid);
        _get_key(key);
        _get_value(value);
        trace_msg($sformatf("get_next() Done. (valid=%b, key=0x%0x, value=0x%0x)", valid, key, value));
    endtask

    // Change value associated with `key`
    task replace(
            input KEY_T key, input VALUE_T new_value, output bit valid, output VALUE_T old_value,
            output bit error, output bit timeout
        );
        _set_key(key);
        _set_value(new_value);
        transact(db_pkg::COMMAND_REPLACE, error, timeout, this._OP_TIMEOUT);
        _get_valid(valid);
        _get_value(old_value);
    endtask

    // Uninstall 'next' entry
    task unset_next(
            output bit valid, output KEY_T key, output VALUE_T value,
            output bit error, output bit timeout
        );
        trace_msg("unset_next()");
        transact(db_pkg::COMMAND_UNSET_NEXT, error, timeout, this._OP_TIMEOUT);
        _get_valid(valid);
        _get_key(key);
        _get_value(value);
        trace_msg("unset_next() Done.");
    endtask

endclass : db_agent
