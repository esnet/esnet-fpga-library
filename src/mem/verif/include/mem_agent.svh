class mem_agent #(
    parameter type ADDR_T = bit,
    parameter type DATA_T = bit
) extends std_verif_pkg::agent;

    local static const string __CLASS_NAME = "mem_verif_pkg::mem_agent";

    //===================================
    // Parameters
    //===================================
    local int __DATA_WID = $bits(DATA_T);
    local int __DATA_BYTES = __DATA_WID % 8 == 0 ? __DATA_WID / 8 : __DATA_WID / 8 + 1;
    protected int _SIZE = 2**$bits(ADDR_T);
    protected int _MAX_BURST_LEN;
    protected int _RESET_TIMEOUT=0;
    protected int _OP_TIMEOUT=0;

    //===================================
    // Methods
    //===================================
    function new(input string name="mem_agent", input int max_burst_len=1);
        super.new(name);
        set_max_burst_len(max_burst_len);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset agent state
    // [[ implements std_verif_pkg::agent.reset() ]]
    function automatic void reset();
        // Nothing to do
    endfunction

    // Set/get (max) burst length (in DATA_T words)
    function automatic void set_max_burst_len(input int max_burst_len);
        localparam int DATA_WID = $bits(DATA_T);
        if (__DATA_WID % 8 == 0) this._MAX_BURST_LEN = max_burst_len;
        else error_msg("For data interfaces that are not sized to an integral number of bytes, only MAX_BURST_LEN == 1 is supported.");
    endfunction

    function int get_max_burst_len();
        return this._MAX_BURST_LEN;
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

    function automatic int _get_burst_len(int _size);
        automatic int __burst_len = _size / __DATA_BYTES;
        if (this._MAX_BURST_LEN == 1 && _size < __DATA_BYTES) return 1;
        else if (_size % __DATA_BYTES != 0) begin
            error_msg("Burst size must be a multiple of DATA width.");
            return 0;
        end else if (__burst_len > this._MAX_BURST_LEN) begin
            error_msg($sformatf("Burst length exceeds max (burst_len: %d; burst_len_max: %d).", __burst_len, this._MAX_BURST_LEN));
            return 0;
        end
        return __burst_len;
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client() ]]
    task reset_client();
        automatic bit error;
        automatic bit timeout;
        clear_all(error, timeout);
        assert (error == 0)   else error_msg("Error detected during RESET_CLIENT operation.");
        assert (timeout == 0) else error_msg("RESET_CLIENT operation timed out.");
    endtask

    // Generic transaction (+ timeout protection)
    task transact(
            input mem_pkg::command_t _command,
            output bit               _error,
            output bit               _timeout,
            input  int               TIMEOUT=0
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

    // Clear all database entries
    task clear_all(output bit error, output bit timeout);
        trace_msg("clear_all()");
        transact(mem_pkg::COMMAND_CLEAR, error, timeout, this._RESET_TIMEOUT);
        trace_msg("clear_all() Done.");
    endtask

    // NOP (null operation; perform req/ack handshake only)
    task nop(output bit error, output bit timeout);
        trace_msg("nop()");
        transact(mem_pkg::COMMAND_NOP, error, timeout, this._OP_TIMEOUT);
        trace_msg("nop() Done.");
    endtask

    // WRITE
    task write(
            input ADDR_T addr, input byte data [],
            output bit error, output bit timeout
        );
        automatic int __size = data.size();
        automatic int __burst_len = _get_burst_len(__size);
        if (__burst_len < 1) error_msg("Write transaction failed. Invalid size.");
        trace_msg($sformatf("write(addr=0x%0x, size=%0dB, data=0x%s)", addr, __size, string_pkg::byte_array_to_hex_string(data)));
        _set_addr(addr);
        _set_burst_len(__burst_len);
        _set_wr_data(data);
        transact(mem_pkg::COMMAND_WRITE, error, timeout, this._OP_TIMEOUT);
        trace_msg("write() Done.");
    endtask

    // READ
    task read(
            input ADDR_T addr, input int size=1,
            output byte data [], output bit error, output bit timeout
        );
        automatic int __burst_len = _get_burst_len(size);
        if (__burst_len < 1) error_msg("Read transaction failed. Invalid size.");
        trace_msg($sformatf("read(addr=0x%0x, size=%0dB)", addr, size));
        _set_addr(addr);
        _set_burst_len(__burst_len);
        transact(mem_pkg::COMMAND_READ, error, timeout, this._OP_TIMEOUT);
        _get_rd_data(size, data);
        trace_msg($sformatf("read() Done. (data=0x%s)", string_pkg::byte_array_to_hex_string(data)));
    endtask
        
    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Generic transaction (no timeout protection)
    virtual task _transact(input mem_pkg::command_t _command, output bit _error); endtask

    // Set address
    virtual task _set_addr(input ADDR_T _addr); endtask

    // Set burst size
    virtual task _set_burst_len(input int _len); endtask

    // Set write data
    virtual task _set_wr_data(input byte _data []); endtask

    // Get read data
    virtual task _get_rd_data(input int _size, output byte _data []); endtask

    // Get memory access type
    virtual task get_access(output mem_pkg::access_t _access); endtask

    // Get memory type
    virtual task get_type(output mem_pkg::mem_type_t _type); endtask

    // Get alignment
    virtual task get_alignment(output int _alignment); endtask

    // Get size
    virtual task get_size(output int _size); endtask

    // Get min burst size
    virtual task get_min_burst_size(output int _min_burst_size); endtask

    // Get max burst size
    virtual task get_max_burst_size(output int _max_burst_size); endtask

endclass : mem_agent
