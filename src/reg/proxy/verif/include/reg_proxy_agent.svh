class reg_proxy_agent #(
    parameter int ADDR_WID = 32,
    parameter int DATA_WID = 32
) extends reg_agent#(ADDR_WID, DATA_WID);

    //===================================
    // Parameters
    //===================================
    local static const string __CLASS_NAME = "reg_verif_pkg::reg_proxy_agent";

    local static const int __DEFAULT_WR_TIMEOUT = 256;
    local static const int __DEFAULT_RD_TIMEOUT = 256;

    //===================================
    // Properties
    //===================================
    local reg_agent#(ADDR_WID, DATA_WID) __reg_agent;
    local int __BASE_OFFSET;

    //===================================
    // Methods
    //===================================

    // Constructor
    function new(
            input string name="reg_proxy_agent",
            const ref reg_agent#(ADDR_WID, DATA_WID) reg_agent_base,
            input int BASE_OFFSET=0
        );
        super.new(name);
        this.set_wr_timeout(__DEFAULT_WR_TIMEOUT);
        this.set_rd_timeout(__DEFAULT_RD_TIMEOUT);
        this.__reg_agent = reg_agent_base;
        this.__BASE_OFFSET = BASE_OFFSET;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset agent
    function automatic void reset();
        // Nothing to do
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset ]]
    task reset_client();
        // AXI-L controller can't reset client
    endtask

    // Put all (driven) interfaces into idle state
    // [[ implements std_verif_pkg::agent.idle ]]
    task idle();
        __reg_agent.idle();
    endtask

    // Wait for specified number of 'cycles', where the definition of a cycle
    // is defined by the client
    // [[ implements std_verif_pkg::agent._wait ]]
    task _wait(input int cycles);
        __reg_agent._wait(cycles);
    endtask

    // Wait for client reset/init to complete
    // [[ implements std_verif_pkg::agent.wait_ready ]]
    task wait_ready();
        __reg_agent.wait_ready();
    endtask

    // Base register access
    task __write_proxy_reg(input addr_t addr, input data_t data);
        trace_msg("__write_proxy_reg()");
        __reg_agent.write_reg(__BASE_OFFSET + addr, data);
        trace_msg("__write_proxy_reg() Done.");
    endtask

    task __read_proxy_reg(input addr_t addr, output data_t data);
        trace_msg("__read_proxy_reg()");
        __reg_agent.read_reg(__BASE_OFFSET + addr, data);
        trace_msg("__read_proxy_reg() Done.");
    endtask

    // Proxy register access
    // COMMAND (32-bit, wr_evt)
    task read_command(output reg_proxy_reg_pkg::reg_command_t reg_command);
        data_t rd_data;
        trace_msg("read_command()");
        __read_proxy_reg(reg_proxy_reg_pkg::OFFSET_COMMAND, rd_data);
        reg_command = reg_proxy_reg_pkg::reg_command_t'(rd_data);
        trace_msg("read_command() Done.");
    endtask

    task write_command(input reg_proxy_reg_pkg::reg_command_t reg_command);
        trace_msg("write_command()");
        __write_proxy_reg(reg_proxy_reg_pkg::OFFSET_COMMAND, reg_command);
        trace_msg("write_command() Done.");
    endtask

    // STATUS (32-bit, rd_evt)
    task read_status(output reg_proxy_reg_pkg::reg_status_t reg_status);
        data_t rd_data;
        trace_msg("read_status()");
        __read_proxy_reg(reg_proxy_reg_pkg::OFFSET_STATUS, rd_data);
        reg_status = reg_proxy_reg_pkg::reg_status_t'(rd_data);
        trace_msg("read_status() Done.");
    endtask

    // ADDRESS (32-bit, rw)
    task read_address(output reg_proxy_reg_pkg::reg_address_t reg_address);
        data_t rd_data;
        trace_msg("read_address()");
        __read_proxy_reg(reg_proxy_reg_pkg::OFFSET_ADDRESS, rd_data);
        reg_address = reg_proxy_reg_pkg::reg_address_t'(rd_data);
        trace_msg("read_address() Done.");
    endtask

    task write_address(input reg_proxy_reg_pkg::reg_address_t reg_address);
        trace_msg("write_address()");
        __write_proxy_reg(reg_proxy_reg_pkg::OFFSET_ADDRESS, reg_address);
        trace_msg("write_address() Done.");
    endtask

    // WR_DATA (32-bit, rw)
    task read_wr_data(output reg_proxy_reg_pkg::reg_wr_data_t reg_wr_data);
        data_t rd_data;
        trace_msg("read_wr_data()");
        __read_proxy_reg(reg_proxy_reg_pkg::OFFSET_WR_DATA, rd_data);
        reg_wr_data = reg_proxy_reg_pkg::reg_wr_data_t'(rd_data);
        trace_msg("read_wr_data() Done.");
    endtask

    task write_wr_data(input reg_proxy_reg_pkg::reg_wr_data_t reg_wr_data);
        trace_msg("write_wr_data()");
        __write_proxy_reg(reg_proxy_reg_pkg::OFFSET_WR_DATA, reg_wr_data);
        trace_msg("write_wr_data() Done.");
    endtask

    // WR_BYTE_EN (32-bit, rw)
    task read_wr_byte_en(output reg_proxy_reg_pkg::reg_wr_byte_en_t reg_wr_byte_en);
        data_t rd_data;
        trace_msg("read_wr_byte_en()");
        __read_proxy_reg(reg_proxy_reg_pkg::OFFSET_WR_BYTE_EN, rd_data);
        reg_wr_byte_en = reg_proxy_reg_pkg::reg_wr_byte_en_t'(rd_data);
        trace_msg("read_wr_byte_en() Done.");
    endtask

    task write_wr_byte_en(input reg_proxy_reg_pkg::reg_wr_byte_en_t reg_wr_byte_en);
        trace_msg("write_wr_byte_en()");
        __write_proxy_reg(reg_proxy_reg_pkg::OFFSET_WR_BYTE_EN, reg_wr_byte_en);
        trace_msg("write_wr_byte_en() Done.");
    endtask

    // RD_DATA (32-bit, ro)
    task read_rd_data(output reg_proxy_reg_pkg::reg_rd_data_t reg_rd_data);
        data_t rd_data;
        trace_msg("read_rd_data()");
        __read_proxy_reg(reg_proxy_reg_pkg::OFFSET_RD_DATA, rd_data);
        reg_rd_data = reg_proxy_reg_pkg::reg_rd_data_t'(rd_data);
        trace_msg("read_rd_data() Done.");
    endtask

    // Proxy register tasks
    task set_address(input addr_t addr);
        reg_proxy_reg_pkg::reg_address_t reg_address;
        trace_msg("set_address()");
        reg_address = addr;
        write_address(addr);
        trace_msg("set_address() Done.");
    endtask

    task set_wr_data(input data_t wr_data);
        reg_proxy_reg_pkg::reg_wr_data_t reg_wr_data;
        trace_msg("set_wr_data()");
        reg_wr_data = wr_data;
        write_wr_data(reg_wr_data);
        trace_msg("set_wr_data() Done.");
    endtask

    task set_wr_byte_en(input bit[3:0] write_byte_en);
        reg_proxy_reg_pkg::reg_wr_byte_en_t reg_wr_byte_en;
        trace_msg("set_wr_byte_en()");
        reg_wr_byte_en.byte_0 = write_byte_en[0];
        reg_wr_byte_en.byte_1 = write_byte_en[1];
        reg_wr_byte_en.byte_2 = write_byte_en[2];
        reg_wr_byte_en.byte_3 = write_byte_en[3];
        write_wr_byte_en(reg_wr_byte_en);
        trace_msg("set_wr_byte_en() Done.");
    endtask

    task get_rd_data(output data_t rd_data);
        reg_proxy_reg_pkg::reg_rd_data_t reg_rd_data;
        trace_msg("get_rd_data()");
        read_rd_data(reg_rd_data);
        rd_data = reg_rd_data;
        trace_msg("get_rd_data() Done.");
    endtask

    task __transact_raw(
            input wr,
            output error
        );
        // Signals
        reg_proxy_reg_pkg::reg_command_t command = 0;
        reg_proxy_reg_pkg::reg_status_t status;

        trace_msg("_transact_raw()");

        // Wait until interface is ready to receive next transaction
        do
            read_status(status);
        while (status.ready == 1'b0);

        if (wr) command.wr_rd_n = 1'b1;

        // Issue command
        write_command(command);

        // Wait for response
        do
            read_status(status);
        while (status.done == 1'b0);

        error = status.error;

        trace_msg("_transact_raw() Done.");
    endtask

    task __transact(
            input wr,
            output error,
            output timeout,
            input TIMEOUT=0
        );
        string cmd_str;
        if (wr) cmd_str = "WR";
        else    cmd_str = "RD";

        trace_msg($sformatf("transact (%s)", cmd_str));

        fork
            begin
                fork
                    begin
                        error = 1'b0;
                        __transact_raw(wr, error);
                    end
                    begin
                        timeout = 1'b0;
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        assert (error == 0)   else info_msg($sformatf("Error detected during '%s' transaction.", cmd_str));
        assert (timeout == 0) else error_msg($sformatf("'%s' transaction timed out.", cmd_str));

        trace_msg($sformatf("transact (%s) Done.", cmd_str));
    endtask

    task _write(
            input addr_t addr,
            input data_t data,
            output bit error,
            output bit timeout,
            output string msg
        );
        trace_msg("_write()");
        set_address(addr);
        set_wr_data(data);
        set_wr_byte_en(4'b1111);
        __transact(1'b1, error, timeout, get_wr_timeout());
        trace_msg("_write() Done.");
    endtask

    task _write_byte(
            input addr_t addr,
            input byte data,
            output bit error,
            output bit timeout,
            output string msg
        );
        addr_t wr_addr;
        logic [3:0][7:0] wr_data = '0;
        logic [3:0] wr_byte_en;
        int byte_pos = addr % 4;

        trace_msg("_write_byte()");

        // Convert byte address to register address
        wr_addr = (addr >> 2) << 2;

        // Convert byte data to register data
        wr_byte_en = 1 << byte_pos;
        wr_data[byte_pos] = data;

        set_address(wr_addr);
        set_wr_data(wr_data);
        set_wr_byte_en(wr_byte_en);
        __transact(1'b1, error, timeout, get_wr_timeout());
        trace_msg("_write_byte() Done.");
    endtask

    task _read(
            input  addr_t addr,
            output data_t data,
            output bit error,
            output bit timeout,
            output string msg
        );
        trace_msg("_read()");
        set_address(addr);
        __transact(1'b0, error, timeout, get_rd_timeout());
        get_rd_data(data);
        trace_msg("_read() Done.");
    endtask

    task _read_byte(
            input  addr_t addr,
            output byte data,
            output bit error,
            output bit timeout,
            output string msg
        );
        logic [3:0][7:0] rd_data;
        int byte_pos = addr % 4;
        addr_t rd_addr;

        trace_msg("_read_byte()");

        // Convert byte address to register address
        rd_addr = (addr >> 2) << 2;

        _read(rd_addr, rd_data, error, timeout, msg);

        // Convert register data to byte data
        data = rd_data[byte_pos];
        trace_msg("_read_byte() Done.");
    endtask

endclass
