// Direct interface agent class for PCI Vital Product Data (VPD) access
class pci_vpd_intf_agent extends pci_vpd_agent;

    local static const string __CLASS_NAME = "pci_vpd_verif_pkg::pci_vpd_intf_agent";

    //===================================
    // Parameters
    //===================================
    localparam int __DEFAULT_WR_TIMEOUT = 50;
    localparam int __DEFAULT_RD_TIMEOUT = 50;

    //===================================
    // Properties
    //===================================
    virtual pci_vpd_intf vpd_vif;

    //===================================
    // Methods
    //===================================

    // Constructor
    function new(
        input string name="pci_vpd_intf_agent",
        input int WR_TIMEOUT = __DEFAULT_WR_TIMEOUT,
        input int RD_TIMEOUT = __DEFAULT_RD_TIMEOUT
    );
        super.new(name);
        this.vpd_vif = null;
        set_wr_timeout(WR_TIMEOUT);
        set_rd_timeout(RD_TIMEOUT);
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

    //===================================
    // Clocking and idle control
    //===================================
    virtual protected task _idle();
        vpd_vif.cb.req <= 1'b0;
        vpd_vif.cb.wr_rd_n <= 1'b0;
        vpd_vif.cb.addr <= '0;
        vpd_vif.cb.wr_data <= '0;
        @(vpd_vif.cb);
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(vpd_vif.cb);
    endtask

    //===================================
    // Byte transactions
    //===================================
    virtual protected task _read_byte(input int addr, output byte data,
                                      output bit error, output bit timeout);
        int cycles = 1;
        int timeout_cycles = get_rd_timeout();
        error = 1'b0;
        timeout = 1'b0;
        data = '0;
        @(vpd_vif.cb);
        vpd_vif.cb.req <= 1'b1;
        vpd_vif.cb.wr_rd_n <= 1'b0;
        vpd_vif.cb.addr <= addr;
        @(vpd_vif.cb);
        vpd_vif.cb.req <= 1'b0;

        // Sample each response on a clocking event; zero disables the timeout.
        while (!vpd_vif.cb.rd_vld) begin
            if (timeout_cycles > 0 && cycles >= timeout_cycles) begin
                timeout = 1'b1;
                return;
            end
            @(vpd_vif.cb);
            cycles++;
        end
        data = vpd_vif.cb.rd_data;
    endtask

    virtual protected task _write_byte(input int addr, input byte data,
                                       output bit error, output bit timeout);
        // The interface has no write acknowledgement: completion is one cycle.
        error = 1'b0;
        timeout = 1'b0;
        @(vpd_vif.cb);
        vpd_vif.cb.req <= 1'b1;
        vpd_vif.cb.wr_rd_n <= 1'b1;
        vpd_vif.cb.addr <= addr;
        vpd_vif.cb.wr_data <= data;
        @(vpd_vif.cb);
        vpd_vif.cb.req <= 1'b0;
    endtask

endclass : pci_vpd_intf_agent
