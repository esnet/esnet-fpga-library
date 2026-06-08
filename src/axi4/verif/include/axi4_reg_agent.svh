// AXI4 register agent
//
// Provides single-beat read and write abstractions over the axi4_intf
// clocking block tasks.  Extends reg_agent so it can participate in the
// standard std_verif_pkg framework alongside axi4l_reg_agent.
//
// For register window use only — single-beat (AxLEN=0) transactions.
// The agent always uses full-bus-width AxSIZE; byte-lane selection within
// the wide data bus is the caller's responsibility via the strb argument.

class axi4_reg_agent #(
    parameter int DATA_BYTE_WID = 64,
    parameter int ADDR_WID      = 64,
    parameter int ID_WID        = 1,
    parameter int USER_WID      = 1
) extends reg_verif_pkg::reg_agent #(ADDR_WID, DATA_BYTE_WID*8);

    //===================================
    // Class Properties
    //===================================
    local static const string __CLASS_NAME = "axi4_verif_pkg::axi4_reg_agent";

    //===================================
    // Interfaces
    //===================================
    virtual axi4_intf #(
        .DATA_BYTE_WID ( DATA_BYTE_WID ),
        .ADDR_WID      ( ADDR_WID      ),
        .ID_WID        ( ID_WID        ),
        .USER_WID      ( USER_WID      )
    ) axi4_vif;

    //===================================
    // Methods
    //===================================

    function new(
            string name = "axi4_reg_agent",
            int    WR_TIMEOUT = 128,
            int    RD_TIMEOUT = 128
        );
        super.new(name);
        set_wr_timeout(WR_TIMEOUT);
        set_rd_timeout(RD_TIMEOUT);
    endfunction

    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Quiesce the AXI4 interface
    // [[ implements std_verif_pkg::component._idle ]]
    task _idle();
        axi4_vif.idle_controller();
    endtask

    // Block for N AXI4 cycles
    // [[ implements std_verif_pkg::agent._wait ]]
    task wait_n(input int cycles);
        axi4_vif._wait(cycles);
    endtask

    // Write — full-bus-width strobe (all bytes enabled)
    // [[ implements reg_verif_pkg::reg_agent._write ]]
    task _write(
            input  addr_t addr,
            input  data_t data,
            output bit    error,
            output bit    timeout,
            output string msg = ""
        );
        axi4_pkg::resp_t resp;
        bit [1:0]        _resp;
        bit [DATA_BYTE_WID-1:0][7:0] _data;

        trace_msg("_write()");

        _data = data;
        axi4_vif.write(addr, _data, '1, _resp, timeout, get_wr_timeout());
        resp  = axi4_pkg::resp_t'(_resp);
        error = (resp != axi4_pkg::RESP_OKAY);

        if (timeout)
            msg = $sformatf("AXI4 write to 0x%0x timed out.", addr);
        else
            msg = $sformatf("AXI4 write to 0x%0x returned '%s'.", addr, resp.encoded.name());

        trace_msg("_write() Done.");
    endtask

    // Read — returns full bus width; caller selects the relevant word lane
    // [[ implements reg_verif_pkg::reg_agent._read ]]
    task _read(
            input  addr_t addr,
            output data_t data,
            output bit    error,
            output bit    timeout,
            output string msg = ""
        );
        axi4_pkg::resp_t resp;
        bit [1:0]        _resp;
        bit [DATA_BYTE_WID-1:0][7:0] _data;

        trace_msg("_read()");

        axi4_vif.read(addr, _data, _resp, timeout, get_rd_timeout());
        resp  = axi4_pkg::resp_t'(_resp);
        data  = _data;
        error = (resp != axi4_pkg::RESP_OKAY);

        if (timeout)
            msg = $sformatf("AXI4 read from 0x%0x timed out.", addr);
        else
            msg = $sformatf("AXI4 read from 0x%0x returned '%s'.", addr, resp.encoded.name());

        trace_msg("_read() Done.");
    endtask

    // Write a single byte at the given byte address.
    // The byte is placed on the correct lane within the wide data bus;
    // all other lanes are masked via the strobe.
    // [[ implements reg_verif_pkg::reg_agent._write_byte ]]
    task _write_byte(
            input  addr_t addr,
            input  byte   data,
            output bit    error,
            output bit    timeout,
            output string msg = ""
        );
        axi4_pkg::resp_t resp;
        bit [1:0]        _resp;
        bit [DATA_BYTE_WID-1:0][7:0] _data = '0;
        bit [DATA_BYTE_WID-1:0]      _strb = '0;
        int byte_pos = int'(addr) % DATA_BYTE_WID;

        trace_msg("_write_byte()");

        _data[byte_pos] = data;
        _strb[byte_pos] = 1'b1;
        axi4_vif.write(addr, _data, _strb, _resp, timeout, get_wr_timeout());
        resp  = axi4_pkg::resp_t'(_resp);
        error = (resp != axi4_pkg::RESP_OKAY);

        if (timeout)
            msg = $sformatf("AXI4 byte write to 0x%0x timed out.", addr);
        else
            msg = $sformatf("AXI4 byte write to 0x%0x returned '%s'.", addr, resp.encoded.name());

        trace_msg("_write_byte() Done.");
    endtask

    // Read a single byte from the given byte address.
    // Issues a full-bus-width read and extracts the relevant byte lane.
    // [[ implements reg_verif_pkg::reg_agent._read_byte ]]
    task _read_byte(
            input  addr_t addr,
            output byte   data,
            output bit    error,
            output bit    timeout,
            output string msg = ""
        );
        axi4_pkg::resp_t resp;
        bit [1:0]        _resp;
        bit [DATA_BYTE_WID-1:0][7:0] _data;
        int byte_pos = int'(addr) % DATA_BYTE_WID;

        trace_msg("_read_byte()");

        axi4_vif.read(addr, _data, _resp, timeout, get_rd_timeout());
        resp  = axi4_pkg::resp_t'(_resp);
        data  = _data[byte_pos];
        error = (resp != axi4_pkg::RESP_OKAY);

        if (timeout)
            msg = $sformatf("AXI4 byte read from 0x%0x timed out.", addr);
        else
            msg = $sformatf("AXI4 byte read from 0x%0x returned '%s'.", addr, resp.encoded.name());

        trace_msg("_read_byte() Done.");
    endtask

endclass : axi4_reg_agent
