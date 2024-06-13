class mem_reg_agent #(
    parameter type ADDR_T = bit,
    parameter type DATA_T = bit
) extends mem_agent#(ADDR_T, DATA_T);

    local static const string __CLASS_NAME = "mem_proxy_verif_pkg::mem_reg_agent";

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BITS = $bits(DATA_T);
    localparam int DATA_BYTES = DATA_BITS % 8 == 0 ? DATA_BITS / 8 : DATA_BITS / 8 + 1;

    //===================================
    // Properties
    //===================================
    mem_proxy_reg_blk_agent reg_blk_agent;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="mem_reg_agent",
            input int max_burst_len,
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
        );
        super.new(name, max_burst_len);
        this.set_reset_timeout(2*this._SIZE);
        this.set_op_timeout(128);
        reg_blk_agent = new("mem_reg_blk_agent", BASE_OFFSET);
        reg_blk_agent.reg_agent = reg_agent;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Put all (driven) interfaces into idle state
    // [[ implements std_verif_pkg::agent.idle ]]
    task idle();
        reg_blk_agent.idle();
    endtask

    // Wait for specified number of 'cycles', where a cycle is defined by
    // the reg_blk_agent (e.g. AXI-L aclk cycles for an AXI-L reg agent)
    // [[ implements std_verif_pkg::agent._wait ]]
    task _wait(input int cycles);
        reg_blk_agent._wait(cycles);
    endtask

    // Wait for client init/reset to complete
    // [[ implements std_verif_pkg::wait_ready virtual method ]]
    task wait_ready();
        mem_proxy_reg_pkg::reg_status_t status;
        trace_msg("--- wait_ready() ---");
        do
            reg_blk_agent.read_status(status);
        while (status.code != mem_proxy_reg_pkg::STATUS_CODE_READY);
        trace_msg("--- wait_ready() Done. ---");
    endtask

    // Generic transaction (no timeout protection)
    // [[ implements db_reg_agent::_transact ]]
    virtual task _transact(
            input mem_pkg::command_t _command,
            output bit               _error
        );
        // Signals
        mem_proxy_reg_pkg::reg_status_t status;
        mem_proxy_reg_pkg::reg_command_t command;

        trace_msg("_transact()");

        // Clear status register
        reg_blk_agent.read_status(status);

        // Issue command
        case (_command)
            mem_pkg::COMMAND_READ        : command.code = mem_proxy_reg_pkg::COMMAND_CODE_READ;
            mem_pkg::COMMAND_READ_BURST  : command.code = mem_proxy_reg_pkg::COMMAND_CODE_READ_BURST;
            mem_pkg::COMMAND_WRITE       : command.code = mem_proxy_reg_pkg::COMMAND_CODE_WRITE;
            mem_pkg::COMMAND_WRITE_BURST : command.code = mem_proxy_reg_pkg::COMMAND_CODE_WRITE_BURST;
            mem_pkg::COMMAND_CLEAR       : command.code = mem_proxy_reg_pkg::COMMAND_CODE_CLEAR;
            default                      : command.code = mem_proxy_reg_pkg::COMMAND_CODE_NOP;
        endcase
        reg_blk_agent.write_command(command);

        // Poll status until done/error/timeout reported
        do
            reg_blk_agent.read_status(status);
        while ((status.done == 1'b0) && (status.error == 1'b0) && (status.timeout == 1'b0));

        _error = status.error || status.timeout;

        trace_msg("_transact() Done.");
    endtask

    // Write address to register
    task _set_addr(input ADDR_T _addr);
        reg_blk_agent.write_addr(_addr);
        debug_msg($sformatf("_set_addr: Wrote 0%0x to addr reg.", _addr));
    endtask

    // Write burst length to control register
    task _set_burst_len(input int _len);
        mem_proxy_reg_pkg::reg_burst_t reg_burst;
        reg_burst.len = _len;
        reg_blk_agent.write_burst(reg_burst);
        debug_msg($sformatf("_set_burst_size: Wrote 0%0x to burst length reg.", _len));
    endtask

    // Load write data registers
    // [[ implements mem_agent::__set_wr_data ]]
    task _set_wr_data(input byte _data []);
        bit [3:0][7:0] wr_data_reg;

        for (int reg_idx = 0; reg_idx < mem_proxy_reg_pkg::COUNT_WR_DATA; reg_idx++) begin
            for (int j = 0; j < 4; j++) begin
                int byte_idx = reg_idx*4 + j;
                if (byte_idx < _data.size()) wr_data_reg[j] = _data[byte_idx];
                else                         wr_data_reg[j] = 0;
            end
            reg_blk_agent.write_wr_data(reg_idx, wr_data_reg);
            debug_msg($sformatf("_set_value: Wrote 0%0x to wr_data reg %0d", wr_data_reg, reg_idx));
        end
    endtask

    // Get read data from registers
    // - requires conversion from array of dwords (with little-endian byte ordering) to array of bytes
    // [[ implements mem_agent::_get_rd_data ]]
    task _get_rd_data(input int _size, output byte _data []);
        automatic int NUM_REGS = _size % 4 == 0 ? _size / 4 : _size / 4 + 1;
        bit [3:0][7:0] rd_data_reg;

        // Allocate output byte array
        _data = new[_size];

        // Build output byte array from register data
        for (int reg_idx = 0; reg_idx < NUM_REGS; reg_idx++) begin
            reg_blk_agent.read_rd_data(reg_idx, rd_data_reg);
            debug_msg($sformatf("_get_rd_data: Read 0%0x from rd_data reg %0d", rd_data_reg, reg_idx));
            for (int i = 0; i < 4; i++) begin
                int byte_idx = reg_idx*4 + i;
                if (byte_idx < _size) _data[byte_idx] = rd_data_reg[i];
            end
        end
        trace_msg($sformatf("_get_rd_data() Done. (value=0x%s)", string_pkg::byte_array_to_hex_string(_data)));
    endtask

    // Get memory access type
    // [[ implements mem_agent.get_access ]]
    task get_access(output mem_pkg::access_t _access);
        mem_proxy_reg_pkg::reg_info_t reg_info;
        reg_blk_agent.read_info(reg_info);
        case(reg_info.access)
            mem_proxy_reg_pkg::INFO_ACCESS_READ_WRITE: _access = mem_pkg::ACCESS_READ_WRITE;
            mem_proxy_reg_pkg::INFO_ACCESS_READ_ONLY:  _access = mem_pkg::ACCESS_READ_ONLY;
            default:                                   _access = mem_pkg::ACCESS_UNSPECIFIED;
        endcase
    endtask

    // Get memory type
    // [[ implements mem_agent.get_type ]]
    task get_type(output mem_pkg::mem_type_t _type);
        mem_proxy_reg_pkg::reg_info_t reg_info;
        reg_blk_agent.read_info(reg_info);
        case(reg_info.mem_type)
            mem_proxy_reg_pkg::INFO_MEM_TYPE_SRAM: _type = mem_pkg::MEM_TYPE_SRAM;
            mem_proxy_reg_pkg::INFO_MEM_TYPE_DDR:  _type = mem_pkg::MEM_TYPE_DDR;
            mem_proxy_reg_pkg::INFO_MEM_TYPE_HBM:  _type = mem_pkg::MEM_TYPE_HBM;
            default:                               _type = mem_pkg::MEM_TYPE_UNSPECIFIED;
        endcase
    endtask

    // Get alignment
    // [[ implements mem_agent.get_alignment ]]
    task get_alignment(output int _alignment);
        mem_proxy_reg_pkg::reg_info_t reg_info;
        reg_blk_agent.read_info(reg_info);
        _alignment = reg_info.alignment;
    endtask

    // Get size
    // [[ implements mem_agent.get_size ]]
    task get_size(output int _size);
        mem_proxy_reg_pkg::reg_info_size_t reg_info_size;
        reg_blk_agent.read_info_size(reg_info_size);
        _size = reg_info_size;
    endtask

    // Get min burst size
    // [[ implements mem_agent.get_min_burst_size ]]
    task get_min_burst_size(output int _min_burst_size);
        mem_proxy_reg_pkg::reg_info_burst_t reg_info_burst;
        reg_blk_agent.read_info_burst(reg_info_burst);
        _min_burst_size = reg_info_burst.min;
    endtask

    // Get max burst size
    // [[ implements mem_agent.get_max_burst_size ]]
    task get_max_burst_size(output int _max_burst_size);
        mem_proxy_reg_pkg::reg_info_burst_t reg_info_burst;
        reg_blk_agent.read_info_burst(reg_info_burst);
        _max_burst_size = reg_info_burst.max;
    endtask

endclass : mem_reg_agent
