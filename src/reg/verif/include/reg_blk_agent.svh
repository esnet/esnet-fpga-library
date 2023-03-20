class reg_blk_agent #(
    parameter int REG_ADDR_WID = 32,
    parameter int REG_DATA_WID = 32
) extends std_verif_pkg::agent;

    local static const string __CLASS_NAME = "reg_verif_pkg::reg_blk_agent";

    //===================================
    // Typedefs
    //===================================
    typedef bit [REG_ADDR_WID-1:0] addr_t;
    typedef bit [REG_DATA_WID-1:0] data_t;

    //===================================
    // Properties
    //===================================
    protected int BASE_ADDR;

    // Register agent
    reg_agent #(.ADDR_WID(REG_ADDR_WID), .DATA_WID(REG_DATA_WID)) reg_agent;

    //===================================
    // Methods
    //===================================

    // Constructor
    function new(input string name, input int BASE_ADDR=0);
        super.new(name);
        this.BASE_ADDR = BASE_ADDR;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset agent
    // [[ implements std_verif_pkg::agent.reset() ]]
    function automatic void reset();
        reg_agent.reset();
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client() ]]
    task reset_client();
        reg_agent.reset_client();
    endtask

    // Put all (driven) interfaces into idle state
    // [[ implements std_verif_pkg::agent.idle() ]]
    task idle();
        reg_agent.idle();
    endtask

    // Wait for specified number of 'cycles', where the definition of a cycle
    // is defined by the client
    // [[ implements std_verif_pkg::agent._wait() ]]
    task _wait(input int cycles);
        reg_agent._wait(cycles);
    endtask

    // Wait for client to be ready
    // [[ implements std_verif_pkg::agent.wait_ready() ]]
    task wait_ready();
        reg_agent.wait_ready();
    endtask

    task _write(input addr_t addr_offset, input data_t data);
        addr_t addr;
        addr = this.BASE_ADDR + addr_offset;
        reg_agent.write_reg(addr, data);
    endtask

    task _read(input addr_t addr_offset, output data_t data);
        addr_t addr;
        addr = this.BASE_ADDR + addr_offset;
        reg_agent.read_reg(addr, data);
    endtask

endclass : reg_blk_agent
