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

class axi4l_reg_agent #(
    parameter int ADDR_WID = 32,
    parameter axi4_pkg::axi4l_bus_width_t BUS_WIDTH = axi4_pkg::AXI4L_BUS_WIDTH_32
) extends reg_verif_pkg::reg_agent#(ADDR_WID, axi4_pkg::get_axi4l_bus_width_in_bytes(BUS_WIDTH)*8);
    
    //===================================
    // Parameters
    //===================================
    localparam int DATA_BYTES = axi4_pkg::get_axi4l_bus_width_in_bytes(BUS_WIDTH);

    //===================================
    // Interfaces
    //===================================
    virtual axi4l_intf #(.ADDR_WID(ADDR_WID), .BUS_WIDTH(BUS_WIDTH)) axil_vif;

    //===================================
    // Methods
    //===================================

    // Constructor
    function new(
            string name="axi4l_reg_agent",
            int WR_TIMEOUT=64,
            int RD_TIMEOUT=64
        );
        super.new(name);
        set_wr_timeout(WR_TIMEOUT);
        set_rd_timeout(RD_TIMEOUT);
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
        axi4_pkg::resp_t resp;
        axil_vif.write(addr, data, resp, timeout, get_wr_timeout());
        if (resp != axi4_pkg::RESP_OKAY) error = 1'b1;
        else                             error = 1'b0;
        if (timeout) msg = $sformatf("AXI-L write to address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L write to address 0x%0x returned with response '%s'.", addr, resp.encoded.name());
    endtask

    task _write_byte(input addr_t addr, input byte data, output bit error, output bit timeout, output string msg="");
        axi4_pkg::resp_t resp;
        axil_vif.write_byte(addr, data, resp, timeout, get_wr_timeout());
        if (resp != axi4_pkg::RESP_OKAY) error = 1'b1;
        else                             error = 1'b0;
        if (timeout) msg = $sformatf("AXI-L byte write to address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L byte write to address 0x%0x returned with response '%s'.", addr, resp.encoded.name());
    endtask

    task _read(input addr_t addr, output data_t data, output bit error, output bit timeout, output string msg="");
        axi4_pkg::resp_t resp;
        axil_vif.read(addr, data, resp, timeout, get_rd_timeout());
        if (resp != axi4_pkg::RESP_OKAY) error = 1'b1;
        else                             error = 1'b0;
        if (timeout) msg = $sformatf("AXI-L read from address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L read from address 0x%0x returned with response '%s'.", addr, resp.encoded.name());
    endtask

    task _read_byte(input addr_t addr, output byte data, output bit error, output bit timeout, output string msg="");
        axi4_pkg::resp_t resp;
        axil_vif.read_byte(addr, data, resp, timeout, get_rd_timeout());
        if (resp != axi4_pkg::RESP_OKAY) error = 1'b1;
        else                             error = 1'b0;
        if (timeout) msg = $sformatf("AXI-L read from address 0x%0x resulted in timeout.", addr);
        else         msg = $sformatf("AXI-L read from address 0x%0x returned with response '%s'.", addr, resp.encoded.name());
    endtask

endclass
