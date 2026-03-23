// Direct interface agent class for PCI Vital Product Data (VPD) access
class pci_vpd_intf_agent extends pci_vpd_agent;

    local static const string __CLASS_NAME = "pci_verif_pkg::pci_vpd_intf_agent";

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

    // Put agent in idle state
    // [[ implements pci_verif_pkg::pci_vpd_agent.idle() ]]
    task idle();
        vpd_vif.idle();
    endtask

    // Read byte from VPD data structure
    // [[ implements pci_verif_pkg::pci_vpd_agent._read_byte() ]]
    protected task automatic _read_byte(input int addr, output byte data, output bit error, output bit timeout);
        error = 1'b0;
        vpd_vif.read(addr, data, timeout, get_wr_timeout());
    endtask

    // Write byte to VPD data structure
    // [[ implements pci_verif_pkg::pci_vpd_agent._write_byte() ]]
    protected task automatic _write_byte(input int addr, input byte data, output bit error, output bit timeout);
        error = 1'b0;
        vpd_vif.write(addr, data, timeout, get_wr_timeout());
    endtask

endclass
