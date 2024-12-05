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
    protected int _BASE_ADDR;

    // Register agent
    reg_agent #(.ADDR_WID(REG_ADDR_WID), .DATA_WID(REG_DATA_WID)) reg_agent;

    //===================================
    // Methods
    //===================================

    // Constructor
    function new(input string name, input int BASE_ADDR=0);
        super.new(name);
        this._BASE_ADDR = BASE_ADDR;
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.reg_agent = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        reg_agent = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Perform register write
    // [[ implements std_verif_pkg::reg_agent._write() ]]
    protected task _write(input addr_t addr_offset, input data_t data);
        addr_t addr;
        addr = this._BASE_ADDR + addr_offset;
        reg_agent.write_reg(addr, data);
    endtask

    // Perform register read
    // [[ implements std_verif_pkg::reg_agent._read() ]]
    protected task _read(input addr_t addr_offset, output data_t data);
        addr_t addr;
        addr = this._BASE_ADDR + addr_offset;
        reg_agent.read_reg(addr, data);
    endtask

endclass : reg_blk_agent
