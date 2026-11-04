class axi4l_reg_agent #(
    parameter int ADDR_WID = 32,
    parameter axi4l_pkg::axi4l_bus_width_t BUS_WIDTH = axi4l_pkg::AXI4L_BUS_WIDTH_32
) extends reg_verif_pkg::reg_agent#(ADDR_WID, axi4l_pkg::get_axi4l_bus_width_in_bytes(BUS_WIDTH)*8);


    //===================================
    // Class Properties
    //===================================
    local static const string __CLASS_NAME = "axi4l_verif_pkg::axi4l_reg_agent";

    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTES = axi4l_pkg::get_axi4l_bus_width_in_bytes(BUS_WIDTH);

    //===================================
    // Interfaces
    //===================================
    virtual axi4l_intf #(.ADDR_WID(ADDR_WID), .BUS_WIDTH(BUS_WIDTH)) axil_vif;

    //===================================
    // Properties
    //===================================
    local bit __randomize_aw_w_alignment;

    //===================================
    // Methods
    //===================================

    // Constructor
    function new(
            string name="axi4l_reg_agent",
            int WR_TIMEOUT=256,
            int RD_TIMEOUT=256
        );
        super.new(name);
        set_wr_timeout(WR_TIMEOUT);
        set_rd_timeout(RD_TIMEOUT);
        set_random_aw_w_alignment(0);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    function automatic void set_random_aw_w_alignment(input bit enable_random_alignment);
        this.__randomize_aw_w_alignment = enable_random_alignment;
    endfunction

    function automatic bit get_random_aw_w_alignment();
        return this.__randomize_aw_w_alignment;
    endfunction

    //===================================
    // Interface control
    //===================================
    // Quiesce AXI-L interface
    // [[ implements std_verif_pkg::component._idle ]]
    task _idle();
        axil_vif.cb.awvalid <= 1'b0;
        axil_vif.cb.awaddr  <=   '0;
        axil_vif.cb.awprot  <= 3'h0;
        axil_vif.cb.wvalid  <= 1'b0;
        axil_vif.cb.wstrb   <=   '0;
        axil_vif.cb.wdata   <=   '0;
        axil_vif.cb.bready  <= 1'b0;
        axil_vif.cb.arvalid <= 1'b0;
        axil_vif.cb.araddr  <=   '0;
        axil_vif.cb.arprot  <= 3'h0;
        axil_vif.cb.rready  <= 1'b0;
        @(axil_vif.cb);
    endtask

    // Block for specified number of AXI-L cycles
    // [[ implements std_verif_pkg::agent._wait ]]
    task wait_n(input int cycles);
        repeat (cycles) @(axil_vif.cb);
    endtask

    //===================================
    // Write transactions
    //===================================
    // Keep clocking-block transfers in the agent rather than calling timed
    // interface tasks through a virtual interface (Verilator 5.054).
    local task _write_raw(
            input  addr_t                  addr,
            input  data_t                  data,
            input  logic [DATA_BYTES-1:0]  strb,
            output axi4l_pkg::resp_t       resp,
            input  bit                     RANDOMIZE_AW_W_ALIGNMENT = 1'b0
        );
        fork
            begin
                if (RANDOMIZE_AW_W_ALIGNMENT) repeat($urandom % 3) @(axil_vif.cb);
                // Write address transaction
                axil_vif.cb.awvalid <= 1'b1;
                axil_vif.cb.awaddr  <= addr;
                @(axil_vif.cb iff (axil_vif.cb.mon_awvalid && axil_vif.cb.awready));
                axil_vif.cb.awvalid <= 1'b0;
                axil_vif.cb.awaddr  <= 'x;
            end
            begin
                if (RANDOMIZE_AW_W_ALIGNMENT) repeat($urandom % 3) @(axil_vif.cb);
                // Write data transaction
                axil_vif.cb.wvalid <= 1'b1;
                axil_vif.cb.wdata  <= data;
                axil_vif.cb.wstrb  <= strb;
                @(axil_vif.cb iff (axil_vif.cb.mon_wvalid && axil_vif.cb.wready));
                axil_vif.cb.wvalid <= 1'b0;
                axil_vif.cb.wdata  <= 'x;
                axil_vif.cb.wstrb  <= 'x;
            end
        join
        // Write response transaction
        axil_vif.cb.bready <= 1'b1;
        @(axil_vif.cb iff (axil_vif.cb.bvalid && axil_vif.cb.mon_bready));
        axil_vif.cb.bready <= 1'b0;
        resp = axil_vif.cb.bresp;
    endtask

    task _write(input addr_t addr, input data_t data, output bit error, output bit timeout, output string msg="");
        automatic bit _timeout = 1'b0;
        automatic axi4l_pkg::resp_t _resp = axi4l_pkg::RESP_SLVERR;
        int WR_TIMEOUT = get_wr_timeout();
        bit RANDOMIZE_AW_W_ALIGNMENT = get_random_aw_w_alignment();

        trace_msg("_write()");
        fork
            begin
                fork
                    begin
                        _write_raw(addr, data, '1, _resp, RANDOMIZE_AW_W_ALIGNMENT);
                    end
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
        if (_resp != axi4l_pkg::RESP_OKAY) error = 1'b1;
        else                               error = 1'b0;
        timeout = _timeout;
        if (timeout) msg = $sformatf("AXI-L write to address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L write to address 0x%0x returned with response '%s'.", addr, _resp.encoded.name());

        trace_msg("_write() Done.");
    endtask

    task _write_byte(input addr_t addr, input byte data, output bit error, output bit timeout, output string msg="");
        addr_t                  addr_aligned;
        data_t                  data_shifted;
        logic [DATA_BYTES-1:0]  strb;
        int                     byte_pos;
        automatic bit           _timeout = 1'b0;
        automatic axi4l_pkg::resp_t _resp = axi4l_pkg::RESP_SLVERR;
        int WR_TIMEOUT = get_wr_timeout();

        addr_aligned = (addr / DATA_BYTES) * DATA_BYTES;
        byte_pos = addr % DATA_BYTES;
        data_shifted = '0;
        strb = '0;
        data_shifted[byte_pos*8 +: 8] = data;
        strb[byte_pos] = 1'b1;

        trace_msg("_write_byte()");
        fork
            begin
                fork
                    begin
                        _write_raw(addr_aligned, data_shifted, strb, _resp, 1'b0);
                    end
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
        if (_resp != axi4l_pkg::RESP_OKAY) error = 1'b1;
        else                               error = 1'b0;
        timeout = _timeout;
        if (timeout) msg = $sformatf("AXI-L byte write to address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L byte write to address 0x%0x returned with response '%s'.", addr, _resp.encoded.name());

        trace_msg("_write_byte() Done.");
    endtask

    //===================================
    // Read transactions
    //===================================
    local task _read_raw(
            input  addr_t             addr,
            output data_t             data,
            output axi4l_pkg::resp_t  resp
        );
        axil_vif.cb.araddr  <= addr;
        axil_vif.cb.rready  <= 1'b0;
        axil_vif.cb.arvalid <= 1'b1;
        @(axil_vif.cb iff (axil_vif.cb.mon_arvalid && axil_vif.cb.arready));
        axil_vif.cb.arvalid <= 1'b0;
        axil_vif.cb.araddr  <= 'x;
        axil_vif.cb.rready  <= 1'b1;
        @(axil_vif.cb iff (axil_vif.cb.rvalid && axil_vif.cb.mon_rready));
        axil_vif.cb.rready  <= 1'b0;
        resp = axil_vif.cb.rresp;
        data = axil_vif.cb.rdata;
    endtask

    task _read(input addr_t addr, output data_t data, output bit error, output bit timeout, output string msg="");
        automatic data_t _data = '0;
        automatic axi4l_pkg::resp_t _resp = axi4l_pkg::RESP_SLVERR;
        automatic bit _timeout = 1'b0;
        int RD_TIMEOUT = get_rd_timeout();

        trace_msg("_read()");
        fork
            begin
                fork
                    begin
                        _read_raw(addr, _data, _resp);
                    end
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
        data = _data;
        if (_resp != axi4l_pkg::RESP_OKAY) error = 1'b1;
        else                               error = 1'b0;
        timeout = _timeout;
        if (timeout) msg = $sformatf("AXI-L read from address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L read from address 0x%0x returned with response '%s'.", addr, _resp.encoded.name());

        trace_msg("_read() Done.");
    endtask

    task _read_byte(input addr_t addr, output byte data, output bit error, output bit timeout, output string msg="");
        addr_t                      addr_aligned;
        logic [DATA_BYTES-1:0][7:0] data_shifted;
        int                         byte_pos;
        automatic data_t            _data = '0;
        automatic axi4l_pkg::resp_t _resp = axi4l_pkg::RESP_SLVERR;
        automatic bit               _timeout = 1'b0;
        int RD_TIMEOUT = get_rd_timeout();

        addr_aligned = (addr / DATA_BYTES) * DATA_BYTES;
        byte_pos = addr % DATA_BYTES;

        trace_msg("_read_byte()");
        fork
            begin
                fork
                    begin
                        _read_raw(addr_aligned, _data, _resp);
                    end
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
        data_shifted = _data;
        data = data_shifted[byte_pos];
        if (_resp != axi4l_pkg::RESP_OKAY) error = 1'b1;
        else                               error = 1'b0;
        timeout = _timeout;
        if (timeout) msg = $sformatf("AXI-L read from address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L read from address 0x%0x returned with response '%s'.", addr, _resp.encoded.name());

        trace_msg("_read_byte() Done.");
    endtask

endclass : axi4l_reg_agent
