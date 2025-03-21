// Base register agent class for verification
// - interface class (can't be instantiated directly)
// - describes interface for 'generic' register agents, where methods are to be implemented by derived class
virtual class reg_agent #(
    parameter int ADDR_WID = 32,
    parameter int DATA_WID = 32
) extends std_verif_pkg::agent;

    local static const string __CLASS_NAME = "reg_verif_pkg::reg_agent";

    //===================================
    // Properties
    //===================================
    protected int _WR_TIMEOUT = 8;
    protected int _RD_TIMEOUT = 8;

    //===================================
    // Typedefs
    //===================================
    typedef bit[ADDR_WID-1:0] addr_t;
    typedef bit[DATA_WID-1:0] data_t;

    //===================================
    // Pure Virtual Methods
    // (to be implemented by subclass)
    //===================================
    pure virtual protected task _write(input addr_t addr, input data_t data, output bit error, output bit timeout, output string msg);
    pure virtual protected task _write_byte(input addr_t addr, input byte data, output bit error, output bit timeout, output string msg);
    pure virtual protected task _read(input addr_t addr, output data_t data, output bit error, output bit timeout, output string msg);
    pure virtual protected task _read_byte(input addr_t addr, output byte data, output bit error, output bit timeout, output string msg);
    pure virtual task wait_n(input int cycles); // Wait specified number of cycles, where cycles is determined by specific instance.

    //===================================
    // Methods
    //===================================

    // Constructor
    function new(input string name="reg_agent");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this._WR_TIMEOUT = 8;
        this._RD_TIMEOUT = 8;
        // } WORKAROUND-INIT-PROPS
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

    function void set_wr_timeout(input int WR_TIMEOUT);
        this._WR_TIMEOUT = WR_TIMEOUT;
    endfunction

    function int get_wr_timeout();
        return this._WR_TIMEOUT;
    endfunction

    function void set_rd_timeout(input int RD_TIMEOUT);
        this._RD_TIMEOUT = RD_TIMEOUT;
    endfunction

    function int get_rd_timeout();
        return this._RD_TIMEOUT;
    endfunction

    task write_reg(input addr_t addr, input data_t data);
        bit error, timeout;
        string msg;

        trace_msg("write_reg()");
        lock(); _write(addr, data, error, timeout, msg); unlock();
        if (error) handle_write_error(addr, msg);
        else if (timeout) handle_write_timeout(addr, msg);

        trace_msg("write_reg() Done.");
    endtask

    task write_byte(input addr_t addr, input byte data);
        bit error, timeout;
        string msg;

        trace_msg("write_byte()");

        lock(); _write_byte(addr, data, error, timeout, msg); unlock();
        if (error) handle_write_error(addr, msg);
        else if (timeout) handle_write_timeout(addr, msg);

        trace_msg("write_byte() Done.");
    endtask

    task read_reg(input addr_t addr, output data_t data);
        bit error, timeout;
        string msg;

        trace_msg("read_reg()");

        lock(); _read(addr, data, error, timeout, msg); unlock();
        if (error) handle_read_error(addr, msg);
        else if (timeout) handle_read_timeout(addr, msg);

        trace_msg("read_reg() Done.");
    endtask

    task read_byte(input addr_t addr, output byte data);
        bit error, timeout;
        string msg;

        trace_msg("read_byte()");

        lock(); _read_byte(addr, data, error, timeout, msg); unlock();
        if (error) handle_read_error(addr, msg);
        else if (timeout) handle_read_timeout(addr, msg);

        trace_msg("read_byte() Done.");
    endtask

    task check_reg(
            input addr_t addr,
            input data_t check_data,
            output bit   check
        );
        data_t rd_data;
        read_reg(addr, rd_data);
        check = (rd_data == check_data);
    endtask

    task write_bad_addr(
            input addr_t addr,
            output bit error,
            output string msg
        );
        bit _error, timeout;
        string _msg;
        lock(); _write(addr, 'h0, _error, timeout, _msg); unlock();
         if (timeout) begin
            error = 1'b1;
            msg = $sformatf("Write to bad address (0x%0x) resulted in timeout\n%s", addr, _msg);
        end else if (_error) begin
            error = 1'b0;
            msg = $sformatf("Write to bad address (0x%0x) detected and handled:\n%s", addr, _msg);
        end else begin
            error = 1'b1;
            msg = $sformatf("Write to bad address (0x%0x) completed unexpectedly\n%s", addr, _msg);
        end
    endtask

    task read_bad_addr(
            input addr_t addr,
            output bit error,
            output string msg
        );
        bit _error, timeout;
        string _msg;
        data_t rd_data_dummy;
        lock(); _read(addr, rd_data_dummy, _error, timeout, _msg); unlock();
        if (timeout) begin
            error = 1'b1;
            msg = $sformatf("Read from bad address (0x%0x) resulted in timeout\n%s", addr, _msg);
        end else if (_error) begin
            error = 1'b0;
            msg = $sformatf("Read from bad address (0x%0x) detected and handled:\n%s", addr, _msg);
        end else begin
            error = 1'b1;
            msg = $sformatf("Read from bad address (0x%0x) completed unexpectedly\n%s", addr, _msg);
        end
    endtask

    function void handle_write_error(input addr_t addr, input string msg);
        $error("%s : ERROR writing to offset 0x%0x\n%s", get_name(), addr, msg);
    endfunction

    function void handle_write_timeout(input addr_t addr, input string msg);
        $error("%s : TIMEOUT writing to offset 0x%0x\n%s", get_name(), addr, msg);
    endfunction

    function void handle_read_error(input addr_t addr, input string msg);
        $error("%s : ERROR reading from offset 0x%0x\n%s", get_name(), addr, msg);
    endfunction

    function void handle_read_timeout(input addr_t addr, input string msg);
        $error("%s : TIMEOUT reading from offset 0x%0x\n%s", get_name(), addr, msg);
    endfunction

endclass
