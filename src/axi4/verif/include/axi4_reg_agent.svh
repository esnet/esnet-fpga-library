// AXI4 register agent
//
// Provides single-beat read and write abstractions over the axi4_intf
// clocking block directly.  Extends reg_agent so it can participate in the
// standard std_verif_pkg framework alongside axi4l_reg_agent.
//
// For register window use only — single-beat (AxLEN=0) transactions.
// Transactions use axi4_pkg::SIZE_4BYTES for 32-bit register windows. Data spans the
// full bus width; byte-lane selection is controlled by write strobes.

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
    localparam int DEFAULT_WR_TIMEOUT = 256;
    localparam int DEFAULT_RD_TIMEOUT = 256;

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

    //===================================
    // Interface control
    //===================================
    task _idle();
        axi4_vif.cb.awvalid  <= 1'b0;
        axi4_vif.cb.awid     <= '0;
        axi4_vif.cb.awaddr   <= '0;
        axi4_vif.cb.awlen    <= 8'h0;
        axi4_vif.cb.awsize   <= axi4_pkg::SIZE_4BYTES;
        axi4_vif.cb.awburst  <= axi4_pkg::BURST_INCR;
        axi4_vif.cb.awlock   <= axi4_pkg::LOCK_NORMAL;
        axi4_vif.cb.awcache  <= '0;
        axi4_vif.cb.awprot   <= '0;
        axi4_vif.cb.awqos    <= '0;
        axi4_vif.cb.awregion <= '0;
        axi4_vif.cb.awuser   <= '0;
        axi4_vif.cb.wvalid   <= 1'b0;
        axi4_vif.cb.wdata    <= '0;
        axi4_vif.cb.wstrb    <= '0;
        axi4_vif.cb.wlast    <= 1'b0;
        axi4_vif.cb.wuser    <= '0;
        axi4_vif.cb.bready   <= 1'b0;
        axi4_vif.cb.arvalid  <= 1'b0;
        axi4_vif.cb.arid     <= '0;
        axi4_vif.cb.araddr   <= '0;
        axi4_vif.cb.arlen    <= 8'h0;
        axi4_vif.cb.arsize   <= axi4_pkg::SIZE_4BYTES;
        axi4_vif.cb.arburst  <= axi4_pkg::BURST_INCR;
        axi4_vif.cb.arlock   <= axi4_pkg::LOCK_NORMAL;
        axi4_vif.cb.arcache  <= '0;
        axi4_vif.cb.arprot   <= '0;
        axi4_vif.cb.arqos    <= '0;
        axi4_vif.cb.arregion <= '0;
        axi4_vif.cb.aruser   <= '0;
        axi4_vif.cb.rready   <= 1'b0;
        @(axi4_vif.cb);
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(axi4_vif.cb);
    endtask

    //===================================
    // Single-beat transfers and deadlines
    //===================================
    // Single-beat read; the public read method provides timeout handling.
    local task _read_raw(
            input  bit [ADDR_WID-1:0]             addr,
            input  bit [ID_WID-1:0]               id,
            input  bit [2:0]                       prot,
            output bit [DATA_BYTE_WID-1:0][7:0]   data,
            output bit [1:0]                       resp
        );
        axi4_vif.cb.arvalid  <= 1'b1;
        axi4_vif.cb.arid     <= id;
        axi4_vif.cb.araddr   <= addr;
        axi4_vif.cb.arlen    <= 8'h0;
        axi4_vif.cb.arsize   <= axi4_pkg::SIZE_4BYTES;
        axi4_vif.cb.arburst  <= axi4_pkg::BURST_INCR;
        axi4_vif.cb.arlock   <= axi4_pkg::LOCK_NORMAL;
        axi4_vif.cb.arprot   <= prot;
        axi4_vif.cb.rready   <= 1'b0;
        @(axi4_vif.cb iff (axi4_vif.cb.mon_arvalid && axi4_vif.cb.arready));
        axi4_vif.cb.arvalid <= 1'b0;
        axi4_vif.cb.araddr  <= 'x;
        axi4_vif.cb.rready  <= 1'b1;
        @(axi4_vif.cb iff (axi4_vif.cb.rvalid && axi4_vif.cb.mon_rready));
        axi4_vif.cb.rready <= 1'b0;
        resp = axi4_vif.cb.rresp;
        data = axi4_vif.cb.rdata;
    endtask

    // Read with a clock-cycle deadline.
    task read(
            input  bit [ADDR_WID-1:0]             addr,
            output bit [DATA_BYTE_WID-1:0][7:0]   data,
            output bit [1:0]                       resp,
            output bit                             timeout,
            input  int                             RD_TIMEOUT = DEFAULT_RD_TIMEOUT
        );
        automatic bit [DATA_BYTE_WID-1:0][7:0] _data    = '0;
        automatic bit [1:0]                    _resp    = axi4_pkg::RESP_SLVERR;
        automatic bit                          _timeout = 1'b0;
        fork
            begin
                fork
                    _read_raw(addr, '0, '0, _data, _resp);
                    begin
                        if (RD_TIMEOUT > 0) begin
                            wait_n(RD_TIMEOUT);
                            _timeout = 1'b1;
                        end else forever wait_n(1);
                    end
                join_any
                disable fork;
            end
        join
        if (_timeout) _idle();
        data    = _data;
        resp    = _resp;
        timeout = _timeout;
    endtask

    // Single-beat write; the public write method provides timeout handling.
    local task _write_raw(
            input  bit [ADDR_WID-1:0]             addr,
            input  bit [DATA_BYTE_WID-1:0][7:0]   data,
            input  bit [DATA_BYTE_WID-1:0]         strb,
            input  bit [ID_WID-1:0]               id,
            input  bit [2:0]                       prot,
            output bit [1:0]                       resp
        );
        // AW and W channels are independent — issue concurrently.
        fork
            begin
                axi4_vif.cb.awvalid  <= 1'b1;
                axi4_vif.cb.awid     <= id;
                axi4_vif.cb.awaddr   <= addr;
                axi4_vif.cb.awlen    <= 8'h0;
                axi4_vif.cb.awsize   <= axi4_pkg::SIZE_4BYTES;
                axi4_vif.cb.awburst  <= axi4_pkg::BURST_INCR;
                axi4_vif.cb.awlock   <= axi4_pkg::LOCK_NORMAL;
                axi4_vif.cb.awprot   <= prot;
                @(axi4_vif.cb iff (axi4_vif.cb.mon_awvalid && axi4_vif.cb.awready));
                axi4_vif.cb.awvalid <= 1'b0;
                axi4_vif.cb.awaddr  <= 'x;
            end
            begin
                axi4_vif.cb.wvalid <= 1'b1;
                axi4_vif.cb.wdata  <= data;
                axi4_vif.cb.wstrb  <= strb;
                axi4_vif.cb.wlast  <= 1'b1;
                @(axi4_vif.cb iff (axi4_vif.cb.mon_wvalid && axi4_vif.cb.wready));
                axi4_vif.cb.wvalid <= 1'b0;
                axi4_vif.cb.wdata  <= 'x;
                axi4_vif.cb.wstrb  <= 'x;
                axi4_vif.cb.wlast  <= 1'b0;
            end
        join
        axi4_vif.cb.bready <= 1'b1;
        @(axi4_vif.cb iff (axi4_vif.cb.bvalid && axi4_vif.cb.mon_bready));
        axi4_vif.cb.bready <= 1'b0;
        resp = axi4_vif.cb.bresp;
    endtask

    // Write with a clock-cycle deadline.
    task write(
            input  bit [ADDR_WID-1:0]             addr,
            input  bit [DATA_BYTE_WID-1:0][7:0]   data,
            input  bit [DATA_BYTE_WID-1:0]         strb,
            output bit [1:0]                       resp,
            output bit                             timeout,
            input  int                             WR_TIMEOUT = DEFAULT_WR_TIMEOUT
        );
        automatic bit [1:0] _resp    = axi4_pkg::RESP_SLVERR;
        automatic bit       _timeout = 1'b0;
        fork
            begin
                fork
                    _write_raw(addr, data, strb, '0, '0, _resp);
                    begin
                        if (WR_TIMEOUT > 0) begin
                            wait_n(WR_TIMEOUT);
                            _timeout = 1'b1;
                        end else forever wait_n(1);
                    end
                join_any
                disable fork;
            end
        join
        if (_timeout) _idle();
        resp    = _resp;
        timeout = _timeout;
    endtask

    //===================================
    // Register-agent API
    //===================================
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
        write(addr, _data, '1, _resp, timeout, get_wr_timeout());
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

        read(addr, _data, _resp, timeout, get_rd_timeout());
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
        write(addr, _data, _strb, _resp, timeout, get_wr_timeout());
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

        read(addr, _data, _resp, timeout, get_rd_timeout());
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
