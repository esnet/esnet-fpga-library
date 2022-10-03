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

class db_reg_agent #(
    parameter type KEY_T = bit[7:0],
    parameter type VALUE_T = bit[31:0]
) extends db_agent#(KEY_T, VALUE_T);

    local static const string __CLASS_NAME = "db_verif_pkg::db_reg_agent";

    //===================================
    // Parameters
    //===================================
    localparam int KEY_BITS   = $bits(KEY_T);
    localparam int VALUE_BITS = $bits(VALUE_T);

    localparam int KEY_BYTES  = KEY_BITS % 8 == 0 ? KEY_BITS / 8 : KEY_BITS / 8 + 1;
    localparam int VALUE_BYTES = VALUE_BITS % 8 == 0 ? VALUE_BITS / 8 : VALUE_BITS / 8 + 1;

    localparam int KEY_REGS = KEY_BYTES % 4 == 0 ? KEY_BYTES / 4 : KEY_BYTES / 4 + 1;
    localparam int VALUE_REGS = VALUE_BYTES % 4 == 0 ? VALUE_BYTES / 4 : VALUE_BYTES / 4 + 1;

    //===================================
    // Properties
    //===================================
    db_reg_blk_agent reg_blk_agent;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="db_reg_agent",
            input int _size,
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
        );
        super.new(name, _size);
        this.set_reset_timeout(2*_size);
        this.set_op_timeout(64);
        reg_blk_agent = new("db_reg_blk_agent", BASE_OFFSET);
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
        db_reg_pkg::reg_status_t status;
        trace_msg("--- wait_ready() ---");
        do
            reg_blk_agent.read_status(status);
        while (status.code != db_reg_pkg::STATUS_CODE_READY);
        trace_msg("--- wait_ready() Done. ---");
    endtask

    // Generic transaction (no timeout protection)
    // [[ implements db_reg_agent::_transact ]]
    virtual task _transact(
            input db_pkg::command_t _command,
            output bit              _error
        );
        // Signals
        db_reg_pkg::reg_status_t status;
        db_reg_pkg::reg_command_t command;

        trace_msg("_transact()");

        // Clear status register
        reg_blk_agent.read_status(status);

        // Issue command
        case (_command)
            db_pkg::COMMAND_GET     : command.code = db_reg_pkg::COMMAND_CODE_GET;
            db_pkg::COMMAND_SET     : command.code = db_reg_pkg::COMMAND_CODE_SET;
            db_pkg::COMMAND_UNSET   : command.code = db_reg_pkg::COMMAND_CODE_UNSET;
            db_pkg::COMMAND_REPLACE : command.code = db_reg_pkg::COMMAND_CODE_REPLACE;
            db_pkg::COMMAND_CLEAR   : command.code = db_reg_pkg::COMMAND_CODE_CLEAR;
            default                 : command.code = db_reg_pkg::COMMAND_CODE_NOP;
        endcase
        reg_blk_agent.write_command(command);

        // Poll status until done/error/timeout reported
        do
            reg_blk_agent.read_status(status);
        while ((status.done == 1'b0) && (status.error == 1'b0) && (status.timeout == 1'b0));

        _error = status.error || status.timeout;

        trace_msg("_transact() Done.");
    endtask

    // Write key to registers
    // - requires conversion from array of bytes to array of dwords (with little-endian byte ordering)
    // [[ implements db_agent::_set_key ]]
    task _set_key(input KEY_T _key);
        int byte_idx;
        bit [0:KEY_BYTES-1][7:0] key_bytes = _key;
        bit [3:0][7:0] key_reg;
        for (int i = 0; i < KEY_REGS; i++) begin
            for (int j = 0; j < 4; j++) begin
                byte_idx = i * 4 + j;
                if (byte_idx < KEY_BYTES) key_reg[j] = key_bytes[byte_idx];
                else                      key_reg[j] = 0;
            end
            reg_blk_agent.write_key(i, key_reg);
            debug_msg($sformatf("_set_key: Wrote 0%0x to key reg %0d", key_reg, i));
        end
    endtask

    // Write value to registers
    // - requires conversion from array of bytes to array of dwords (with little-endian byte ordering)
    // [[ implements db_agent::_set_value ]]
    task _set_value(input VALUE_T _value);
        int byte_idx;
        bit [0:VALUE_BYTES-1][7:0] value_bytes = _value;
        bit [3:0][7:0] value_reg;
        for (int i = 0; i < VALUE_REGS; i++) begin
            for (int j = 0; j < 4; j++) begin
                byte_idx = i * 4 + j;
                if (byte_idx < VALUE_BYTES) value_reg[j] = value_bytes[byte_idx];
                else                        value_reg[j] = 0;
            end
            reg_blk_agent.write_set_value(i, value_reg);
            debug_msg($sformatf("_set_value: Wrote 0%0x to value reg %0d", value_reg, i));
        end
    endtask

    // Read value from registers
    // - requires conversion from array of dwords (with little-endian byte ordering) to array of bytes
    // [[ implements db_agent::_get_value ]]
    task _get_value(output VALUE_T _value);
        int byte_idx;
        bit [0:VALUE_BYTES-1][7:0] value_bytes;
        bit [3:0][7:0] value_reg;
        trace_msg("_get_value()");
        for (int i = 0; i < VALUE_REGS; i++) begin
            reg_blk_agent.read_get_value(i, value_reg);
            debug_msg($sformatf("_get_value: Read 0%0x from value reg %0d", value_reg, i));
            for (int j = 0; j < 4; j++) begin
                byte_idx = i * 4 + j;
                if (byte_idx < VALUE_BYTES) value_bytes[byte_idx] = value_reg[j];
            end
        end
        _value = value_bytes;
        trace_msg($sformatf("_get_value() Done. (value=0x%0x)", _value));
    endtask

    // Read valid register
    // [[ implements db_agent::_get_valid ]]
    task _get_valid(output bit _valid);
        db_reg_pkg::reg_get_valid_t reg_get_valid;
        trace_msg("_get_valid()");
        reg_blk_agent.read_get_valid(reg_get_valid);
        _valid = reg_get_valid.value;
        trace_msg($sformatf("_get_valid() Done. (valid=%b)", _valid));
    endtask

    // Get database type
    // [[ implements db_agent.get_type ]]
    task get_type(output db_pkg::type_t _type);
        db_reg_pkg::reg_info_t reg_info;

        // Read database type from info register
        reg_blk_agent.read_info(reg_info);

        case(reg_info.db_type)
            db_reg_pkg::INFO_DB_TYPE_STASH  : _type = db_pkg::DB_TYPE_STASH;
            db_reg_pkg::INFO_DB_TYPE_HTABLE : _type = db_pkg::DB_TYPE_HTABLE;
            db_reg_pkg::INFO_DB_TYPE_STATE  : _type = db_pkg::DB_TYPE_STATE;
            default                         : _type = db_pkg::DB_TYPE_UNSPECIFIED;
        endcase
    endtask

    // Get database subtype
    // [[ implements db_agent.get_type ]]
    task get_subtype(output db_pkg::subtype_t _subtype);
        db_reg_pkg::reg_info_t reg_info;

        // Read database type from info register
        reg_blk_agent.read_info(reg_info);

        _subtype = reg_info.db_subtype;
    endtask

    // Query database size
    // [[ implements db_agent.get_size ]]
    task get_size(output int _size);
        db_reg_pkg::reg_info_size_t reg_info_size;

        // Read database size from info_size register
        reg_blk_agent.read_info_size(reg_info_size);
        _size = reg_info_size;
    endtask

    // Query database fill level
    // [[ implements db_agent.get_fill ]]
    task get_fill(output int _fill);
        db_reg_pkg::reg_status_fill_t reg_status_fill;

        // Read database fill from status_fill register
        reg_blk_agent.read_status_fill(reg_status_fill);
        _fill = reg_status_fill;
    endtask

    task get_key_bits(output int key_bits);
        db_reg_pkg::reg_info_key_t reg_info_key;

        // Read number of key bits from info_key register
        reg_blk_agent.read_info_key(reg_info_key);
        key_bits = reg_info_key.bits;
    endtask

    task get_key_bytes(output int key_bytes);
        db_reg_pkg::reg_info_key_t reg_info_key;

        // Read number of key bytes from info_key register
        reg_blk_agent.read_info_key(reg_info_key);
        key_bytes = reg_info_key.bytes;
    endtask

    task get_key_regs(output int key_regs);
        db_reg_pkg::reg_info_key_t reg_info_key;

        // Read number of key regs from info_key register
        reg_blk_agent.read_info_key(reg_info_key);
        key_regs = reg_info_key.regs;
    endtask

    task get_value_bits(output int value_bits);
        db_reg_pkg::reg_info_value_t reg_info_value;

        // Read number of value bits from info_value register
        reg_blk_agent.read_info_value(reg_info_value);
        value_bits = reg_info_value.bits;
    endtask

    task get_value_bytes(output int value_bytes);
        db_reg_pkg::reg_info_value_t reg_info_value;

        // Read number of value bytes from info_value register
        reg_blk_agent.read_info_value(reg_info_value);
        value_bytes = reg_info_value.bytes;
    endtask

    task get_value_regs(output int value_regs);
        db_reg_pkg::reg_info_value_t reg_info_value;

        // Read number of value regs from info_value register
        reg_blk_agent.read_info_value(reg_info_value);
        value_regs = reg_info_value.regs;
    endtask

endclass : db_reg_agent
