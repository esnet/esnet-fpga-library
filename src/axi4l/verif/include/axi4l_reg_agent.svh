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
            int WR_TIMEOUT=128,
            int RD_TIMEOUT=128
        );
        super.new(name);
        set_wr_timeout(WR_TIMEOUT);
        set_rd_timeout(RD_TIMEOUT);
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

    // Reset agent
    protected virtual function automatic void _reset();
        super._reset();
        // Nothing else to do
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        // AXI-L controller can't reset client
    endtask

    // Put all (driven) interfaces into idle state
    // [[ implements std_verif_pkg::agent.idle ]]
    task idle();
        axil_vif.idle_controller();
    endtask

    // Wait for specified number of 'cycles', where the definition of a cycle
    // is defined by the client
    // [[ implements std_verif_pkg::agent._wait ]]
    task _wait(input int cycles);
        axil_vif._wait(cycles);
    endtask

    // Wait for client reset/init to complete
    // [[ implements std_verif_pkg::agent.wait_ready ]]
    task wait_ready();
        // No mechanism for client to report readiness; assume
        // ready when out of reset
    endtask

    task _write(input addr_t addr, input data_t data, output bit error, output bit timeout, output string msg="");
        axi4l_pkg::resp_t resp;

        trace_msg("_write()");

        axil_vif.write(addr, data, resp, timeout, get_wr_timeout(), get_random_aw_w_alignment());
        if (resp != axi4l_pkg::RESP_OKAY) error = 1'b1;
        else                              error = 1'b0;
        if (timeout) msg = $sformatf("AXI-L write to address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L write to address 0x%0x returned with response '%s'.", addr, resp.encoded.name());

        trace_msg("_write() Done.");
    endtask

    task _write_byte(input addr_t addr, input byte data, output bit error, output bit timeout, output string msg="");
        axi4l_pkg::resp_t resp;

        trace_msg("_write_byte()");

        axil_vif.write_byte(addr, data, resp, timeout, get_wr_timeout());
        if (resp != axi4l_pkg::RESP_OKAY) error = 1'b1;
        else                              error = 1'b0;
        if (timeout) msg = $sformatf("AXI-L byte write to address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L byte write to address 0x%0x returned with response '%s'.", addr, resp.encoded.name());

        trace_msg("_write_byte()");
    endtask

    task _read(input addr_t addr, output data_t data, output bit error, output bit timeout, output string msg="");
        axi4l_pkg::resp_t resp;

        trace_msg("_read()");

        axil_vif.read(addr, data, resp, timeout, get_rd_timeout());
        if (resp != axi4l_pkg::RESP_OKAY) error = 1'b1;
        else                              error = 1'b0;
        if (timeout) msg = $sformatf("AXI-L read from address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L read from address 0x%0x returned with response '%s'.", addr, resp.encoded.name());

        trace_msg("_read() Done.");
    endtask

    task _read_byte(input addr_t addr, output byte data, output bit error, output bit timeout, output string msg="");
        axi4l_pkg::resp_t resp;

        trace_msg("_read_byte()");

        axil_vif.read_byte(addr, data, resp, timeout, get_rd_timeout());
        if (resp != axi4l_pkg::RESP_OKAY) error = 1'b1;
        else                             error = 1'b0;
        if (timeout) msg = $sformatf("AXI-L read from address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L read from address 0x%0x returned with response '%s'.", addr, resp.encoded.name());

        trace_msg("_read_byte() Done.");
    endtask

endclass
