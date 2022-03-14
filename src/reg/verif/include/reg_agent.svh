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

class reg_agent #(
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
    // Virtual Methods
    // (to be implemented by subclass)
    //===================================
    virtual task _write(input addr_t addr, input data_t data, output bit error, output bit timeout, output string msg); endtask
    virtual task _write_byte(input addr_t addr, input byte data, output bit error, output bit timeout, output string msg); endtask
    virtual task _read(input addr_t addr, output data_t data, output bit error, output bit timeout, output string msg); endtask
    virtual task _read_byte(input addr_t addr, output byte data, output bit error, output bit timeout, output string msg); endtask

    //===================================
    // Methods
    //===================================

    // Constructor
    function new(input string name="reg_agent");
        super.new(name);
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
        _write(addr, data, error, timeout, msg);
        if (error) handle_write_error(addr, msg);
        else if (timeout) handle_write_timeout(addr, msg);
    endtask

    task write_byte(input addr_t addr, input byte data);
        bit error, timeout;
        string msg;
        _write_byte(addr, data, error, timeout, msg);
        if (error) handle_write_error(addr, msg);
        else if (timeout) handle_write_timeout(addr, msg);
    endtask

    task read_reg(input addr_t addr, output data_t data);
        bit error, timeout;
        string msg;
        _read(addr, data, error, timeout, msg);
        if (error) handle_read_error(addr, msg);
        else if (timeout) handle_read_timeout(addr, msg);
    endtask

    task read_byte(input addr_t addr, output byte data);
        bit error, timeout;
        string msg;
        _read_byte(addr, data, error, timeout, msg);
        if (error) handle_read_error(addr, msg);
        else if (timeout) handle_read_timeout(addr, msg);
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
        _write(addr, 'h0, _error, timeout, _msg);
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
        _read(addr, rd_data_dummy, _error, timeout, _msg);
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
