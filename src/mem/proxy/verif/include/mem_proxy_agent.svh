class mem_proxy_agent extends mem_proxy_reg_blk_agent;

    local static const string __CLASS_NAME = "mem_proxy_verif_pkg::mem_proxy_agent";

    //===================================
    // Parameters
    //===================================
    local int __RESET_TIMEOUT;
    local int __OP_TIMEOUT;

    local const int __SIZE;
    local const int __DATA_WID;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="mem_proxy_agent",
            input int size,
            input int data_wid,
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
        );
        super.new(name, BASE_OFFSET);
        this.__SIZE = size;
        this.__DATA_WID = data_wid;
        this.set_reset_timeout(2*size);
        this.set_op_timeout(128);
        this.reg_agent = reg_agent;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Get data width (in bits)
    function automatic int get_data_wid();
        return this.__DATA_WID;
    endfunction

    // Get data width (in bytes)
    function automatic int get_data_byte_wid();
        if (this.__DATA_WID % 8 == 0) return this.__DATA_WID / 8;
        else                          return this.__DATA_WID / 8 + 1;
    endfunction

    // Get (max) burst length
    function automatic int get_max_burst_len();
        if (this.__DATA_WID % 8 == 0) return (mem_proxy_reg_pkg::COUNT_WR_DATA * 4 / get_data_byte_wid());
        else                          return 1;
    endfunction

    function automatic int get_window_size();
        return get_max_burst_len() * get_data_byte_wid();
    endfunction

    // Set timeout (in cycles) for reset operation
    function automatic void set_reset_timeout(input int RESET_TIMEOUT);
        this.__RESET_TIMEOUT = RESET_TIMEOUT;
    endfunction

    // Set timeout (in cycles) for non-reset operations
    function automatic void set_op_timeout(input int OP_TIMEOUT);
        this.__OP_TIMEOUT = OP_TIMEOUT;
    endfunction

    // Get timeout (in cycles) for reset operation
    function automatic int get_reset_timeout();
        return this.__RESET_TIMEOUT;
    endfunction

    // Get timeout (in cycles) for non-reset operations
    function automatic int get_op_timeout();
        return this.__OP_TIMEOUT;
    endfunction

    // Calculate burst length from size in bytes
    function automatic int _get_burst_len(int _size);
        automatic int __DATA_BYTES = get_data_byte_wid();
        automatic int __MAX_BURST_LEN = get_max_burst_len();
        automatic int __burst_len = _size % __DATA_BYTES == 0 ? _size / __DATA_BYTES : _size / __DATA_BYTES + 1;
        if (__burst_len > __MAX_BURST_LEN) begin
            error_msg($sformatf("Burst length exceeds max (burst_len: %d; burst_len_max: %d).", __burst_len, __MAX_BURST_LEN));
            return 0;
        end
        return __burst_len;
    endfunction

    // Wait for client init/reset to complete
    // [[ implements std_verif_pkg::wait_ready virtual method ]]
    task wait_ready();
        automatic mem_proxy_reg_pkg::reg_status_t status;
        trace_msg("--- wait_ready() ---");
        do
            this.read_status(status);
        while (status.code != mem_proxy_reg_pkg::STATUS_CODE_READY);
        trace_msg("--- wait_ready() Done. ---");
    endtask

    // Perform any necessary initialization, etc. and block until agent is ready for processing
    // [[ overrides std_verif_pkg::agent._init() ]]
    protected virtual task _init();
        automatic bit error;
        automatic bit timeout;
        trace_msg("init()");
        clear_all(error, timeout);
        if (error) error_msg("Init failed with error.");
        else if (timeout) error_msg("Init failed with timeout.");
        trace_msg("init() Done.");
    endtask

    // Generic transaction (no timeout protection)
    virtual task _transact(
            input mem_pkg::command_t _command,
            output bit               _error
        );
        // Signals
        mem_proxy_reg_pkg::reg_status_t status;
        mem_proxy_reg_pkg::reg_command_t command;

        trace_msg("_transact()");

        // Clear status register
        this.read_status(status);

        // Issue command
        case (_command)
            mem_pkg::COMMAND_READ        : command.code = mem_proxy_reg_pkg::COMMAND_CODE_READ;
            mem_pkg::COMMAND_WRITE       : command.code = mem_proxy_reg_pkg::COMMAND_CODE_WRITE;
            mem_pkg::COMMAND_CLEAR       : command.code = mem_proxy_reg_pkg::COMMAND_CODE_CLEAR;
            default                      : command.code = mem_proxy_reg_pkg::COMMAND_CODE_NOP;
        endcase
        this.write_command(command);

        // Poll status until done/error/timeout reported
        do
            this.read_status(status);
        while ((status.done == 1'b0) && (status.error == 1'b0) && (status.timeout == 1'b0));

        _error = status.error || status.timeout;

        trace_msg("_transact() Done.");
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
                            this.reg_agent.wait_n(TIMEOUT);
                            _timeout = 1'b1;
                        end else wait (0);
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
        transact(mem_pkg::COMMAND_CLEAR, error, timeout, get_reset_timeout());
        trace_msg("clear_all() Done.");
    endtask

    // NOP (null operation; perform req/ack handshake only)
    task nop(output bit error, output bit timeout);
        trace_msg("nop()");
        transact(mem_pkg::COMMAND_NOP, error, timeout, get_op_timeout());
        trace_msg("nop() Done.");
    endtask

    // WRITE
    task write(
            input int addr, input byte data [],
            output bit error, output bit timeout
        );
        automatic byte __data[$] = data;
        automatic byte __wr_data[$];
        automatic int burst_bytes=0;
        automatic int burst_len;
        trace_msg($sformatf("write(addr=0x%0x, size=%0dB, data=0x%s)", addr, data.size(), string_pkg::byte_array_to_hex_string(data)));
        // Check for empty input byte array
        if (data.size() < 1) begin
            debug_msg("Zero-length data. Nothing to write.");
            return;
        end
        // Write byte array to memory in max-size bursts
        while (__data.size() > 0) begin
            // Initialize
            __wr_data.delete();
            burst_bytes = 0;
            // Write data to memory proxy window
            for (int i = 0; i < get_window_size(); i++) begin
                if (__data.size() > 0) begin
                    __wr_data.push_back(__data.pop_front());
                    burst_bytes++;
                end else __wr_data.push_back('0);
            end
            _set_wr_data(__wr_data);
            // Configure transaction
            _set_addr(addr);
            burst_len = _get_burst_len(burst_bytes);
            _set_burst_len(burst_len);
            // Execute transaction
            transact(mem_pkg::COMMAND_WRITE, error, timeout, get_op_timeout());
            if (error || timeout) return;
            // Increment address
            addr += burst_len;
        end
        __data.delete();
        trace_msg("write() Done.");
    endtask

    // READ
    task read(
            input int addr, input int size=1,
            output byte data [], output bit error, output bit timeout
        );
        automatic byte __data[$];
        automatic byte __rd_data[$];
        automatic int burst_bytes;
        automatic int burst_len;
        trace_msg($sformatf("read(addr=0x%0x, size=%0dB)", addr, size));
        // Read memory to byte array in max-size bursts
        while (__data.size() < size) begin
            // Initialize
            burst_bytes = (size - __data.size()) > get_window_size() ? get_window_size() : (size - __data.size());
            // Configure transaction
            _set_addr(addr);
            burst_len = _get_burst_len(burst_bytes);
            _set_burst_len(burst_len);
            // Execute transaction
            transact(mem_pkg::COMMAND_READ, error, timeout, get_op_timeout());
            if (error || timeout) return;
            // Read data from memory proxy window
            _get_rd_data(burst_bytes, __rd_data);
            while (__rd_data.size() > 0) __data.push_back(__rd_data.pop_front());
            // Increment address
            addr += burst_len;
            // Clean up
            __rd_data.delete();
        end
        data = __data;
        // Clean up
        __data.delete();
        trace_msg($sformatf("read() Done. (data=0x%s)", string_pkg::byte_array_to_hex_string(data)));
    endtask

    // Write address to register
    task _set_addr(input int _addr);
        this.write_addr(_addr);
        debug_msg($sformatf("_set_addr: Wrote 0%0x to addr reg.", _addr));
    endtask

    // Write burst length to control register
    task _set_burst_len(input int _len);
        mem_proxy_reg_pkg::reg_burst_t reg_burst;
        reg_burst.len = _len;
        this.write_burst(reg_burst);
        debug_msg($sformatf("_set_burst_size: Wrote 0%0x to burst length reg.", _len));
    endtask

    // Load write data registers
    task _set_wr_data(input byte _data []);
        bit [3:0][7:0] wr_data_reg;

        for (int reg_idx = 0; reg_idx < mem_proxy_reg_pkg::COUNT_WR_DATA; reg_idx++) begin
            for (int j = 0; j < 4; j++) begin
                int byte_idx = reg_idx*4 + j;
                if (byte_idx < _data.size()) wr_data_reg[j] = _data[byte_idx];
                else                         wr_data_reg[j] = 0;
            end
            this.write_wr_data(reg_idx, wr_data_reg);
            debug_msg($sformatf("_set_value: Wrote 0%0x to wr_data reg %0d", wr_data_reg, reg_idx));
        end
    endtask

    // Get read data from registers
    // - requires conversion from array of dwords (with little-endian byte ordering) to array of bytes
    task _get_rd_data(input int _size, output byte _data []);
        automatic int NUM_REGS = _size % 4 == 0 ? _size / 4 : _size / 4 + 1;
        bit [3:0][7:0] rd_data_reg;

        // Allocate output byte array
        _data = new[_size];

        // Build output byte array from register data
        for (int reg_idx = 0; reg_idx < NUM_REGS; reg_idx++) begin
            this.read_rd_data(reg_idx, rd_data_reg);
            debug_msg($sformatf("_get_rd_data: Read 0%0x from rd_data reg %0d", rd_data_reg, reg_idx));
            for (int i = 0; i < 4; i++) begin
                int byte_idx = reg_idx*4 + i;
                if (byte_idx < _size) _data[byte_idx] = rd_data_reg[i];
            end
        end
        trace_msg($sformatf("_get_rd_data() Done. (value=0x%s)", string_pkg::byte_array_to_hex_string(_data)));
    endtask

    // Get memory access type
    task get_access(output mem_pkg::access_t _access);
        mem_proxy_reg_pkg::reg_info_t reg_info;
        this.read_info(reg_info);
        case(reg_info.access)
            mem_proxy_reg_pkg::INFO_ACCESS_READ_WRITE: _access = mem_pkg::ACCESS_READ_WRITE;
            mem_proxy_reg_pkg::INFO_ACCESS_READ_ONLY:  _access = mem_pkg::ACCESS_READ_ONLY;
            default:                                   _access = mem_pkg::ACCESS_UNSPECIFIED;
        endcase
    endtask

    // Get memory type
    task get_type(output mem_pkg::mem_type_t _type);
        mem_proxy_reg_pkg::reg_info_t reg_info;
        this.read_info(reg_info);
        case(reg_info.mem_type)
            mem_proxy_reg_pkg::INFO_MEM_TYPE_SRAM: _type = mem_pkg::MEM_TYPE_SRAM;
            mem_proxy_reg_pkg::INFO_MEM_TYPE_DDR:  _type = mem_pkg::MEM_TYPE_DDR;
            mem_proxy_reg_pkg::INFO_MEM_TYPE_HBM:  _type = mem_pkg::MEM_TYPE_HBM;
            default:                               _type = mem_pkg::MEM_TYPE_UNSPECIFIED;
        endcase
    endtask

    // Get alignment
    task get_alignment(output int _alignment);
        mem_proxy_reg_pkg::reg_info_t reg_info;
        this.read_info(reg_info);
        _alignment = reg_info.alignment;
    endtask

    // Get depth
    task get_depth(output int _depth);
        mem_proxy_reg_pkg::reg_info_depth_t reg_info_depth;
        this.read_info_depth(reg_info_depth);
        _depth = reg_info_depth;
    endtask

    // Get size
    task get_size(output int _size);
        mem_proxy_reg_pkg::reg_info_size_t reg_info_size;
        this.read_info_size(reg_info_size);
        _size = reg_info_size;
    endtask

    // Get min burst size
    task get_min_burst_size(output int _min_burst_size);
        mem_proxy_reg_pkg::reg_info_burst_t reg_info_burst;
        this.read_info_burst(reg_info_burst);
        _min_burst_size = reg_info_burst.min;
    endtask

    // Get max burst size
    task get_max_burst_size(output int _max_burst_size);
        mem_proxy_reg_pkg::reg_info_burst_t reg_info_burst;
        this.read_info_burst(reg_info_burst);
        _max_burst_size = reg_info_burst.max;
    endtask

endclass : mem_proxy_agent
