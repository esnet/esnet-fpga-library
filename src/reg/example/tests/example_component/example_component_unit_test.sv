`include "svunit_defines.svh"

module example_component_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "example_component_ut";
    svunit_testcase svunit_ut;

    //===================================
    // This is the UUT that we're 
    // running the Unit Tests on
    //===================================
    
    // Clock/reset
    logic clk;

    // AXI-L interface
    axi4l_intf axil_if ();

    // Component ports
    logic        input_valid;
    logic [31:0] input_data;
    logic        output_valid;
    logic [31:0] output_data;

    // Implicitly connect signals to UUT
    example_component UUT(.*);

    //===================================
    // Environment
    //===================================
    std_reset_intf #(.ACTIVE_LOW(1)) reset_if (.clk(axil_if.aclk));

    // Assign reset interface
    assign axil_if.aresetn = reset_if.reset;
    initial reset_if.ready = axil_if.aresetn;

    // Connect input/output interfaces
    assign input_valid = output_valid;
    assign input_data = output_data;

    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(axil_if.aclk, 5ns);

    // Datapath clock is synchronous to AXI-L clock
    assign clk = axil_if.aclk;

    // AXI4-L register agent
    //
    // Executes register read/write transactions over the AXI-L control
    // interface.
    axi4l_verif_pkg::axi4l_reg_agent axil_reg_agent;
    
    // Register block agent
    // 
    // This is a custom agent class that is autogenerated by regio
    // based on the example.yaml register block specification.
    //
    // The agent class contains per-register write/read methods, allowing
    // registers to be referred to by name in the test code (rather than
    // by address) which improves readability and maintainability. Also,
    // the methods take as input (for writes) and return as output (for reads)
    // data types that correspond to the register format.
    //
    // The `build` function below illustrates how an object of this agent
    // class is created and connected to the underlying register infrastructure.
    //
    // The unit tests illustrate how to read/write registers using the agent.
    reg_example_reg_verif_pkg::example_reg_blk_agent reg_blk_agent;
    
    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Create agents
        axil_reg_agent = new();
        reg_blk_agent = new();

        // Connect 'physical' AXI-L interface to 'virtual' AXI-L interface
        // of AXI-L register agent
        //
        // This is the interface that the AXI-L register agent will use to 
        // execute (raw) register read/write transactions
        axil_reg_agent.axil_vif = axil_if;

        // Connect AXI-L (raw) register agent to the block-specific agent
        //
        // Internally, the register block agent needs access to a low-level
        // agent that knows how to issue 'raw' read and write transactions.
        // Since we are using an AXI-L control interface, this access is provided
        // by connecting setting the internal 'reg_agent' reference to the AXI-L
        // agent instantiated within the test environment:
        reg_blk_agent.reg_agent = axil_reg_agent;

    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        /* Place Setup Code Here */

        // Quiesce AXI-L control interface
        axil_if.idle_controller();

        // Assert/deassert reset
        reset_if.pulse(8);

    endtask


    //===================================
    // Here we deconstruct anything we 
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();
        /* Place Teardown Code Here */

    endtask


    //===================================
    // All tests are defined between the
    // SVUNIT_TESTS_BEGIN/END macros
    //
    // Each individual test must be
    // defined between `SVTEST(_NAME_)
    // `SVTEST_END
    //
    // i.e.
    //   `SVTEST(mytest)
    //     <test code>
    //   `SVTEST_END
    //===================================
    `SVUNIT_TESTS_BEGIN

    // Read-Write register test
    // Verify the init value from the register.
    // Perform a write of some other value, read back and compare.
    `SVTEST(rw_example)
        // Declare input/output signals as custom register types
        example_reg_pkg::reg_rw_example_t exp_data;
        example_reg_pkg::reg_rw_example_t got_data;

        // Read init value from register
        // -------------------------------------
        // Reg package includes init values:
        exp_data = example_reg_pkg::INIT_RW_EXAMPLE;
        // Read from register using custom read method
        reg_blk_agent.read_rw_example(got_data);
        // Check against expected data:
        `FAIL_UNLESS(got_data == exp_data);

        // Write new value to register
        // -------------------------------------
        // Set register values to some value (can set fields by name):
        exp_data.field0 = 8'h45;
        exp_data.field1 = example_reg_pkg::RW_EXAMPLE_FIELD1_ABC;
        // Write value to register using custom write method
        reg_blk_agent.write_rw_example(exp_data);
        // Read value back
        reg_blk_agent.read_rw_example(got_data);
        // Check got against expected:
        `FAIL_UNLESS(got_data == exp_data);

    `SVTEST_END

    // Read-Write array test
    // Perform writes to each of the registers in the array; read all
    // values back and compare.
    `SVTEST(rw_array_example)
        // This time, import all symbols from the register definitions
        // package into the test scope to avoid needing the explicit
        // package prefix:
        import example_reg_pkg::*;
        // Declare input/output signals as custom register types
        reg_rw_array_example_t exp_data[COUNT_RW_ARRAY_EXAMPLE];
        reg_rw_array_example_t got_data[COUNT_RW_ARRAY_EXAMPLE];

        // Write new value to register
        // -------------------------------------
        // Initialize data vector
        for (int i = 0; i < COUNT_RW_ARRAY_EXAMPLE; i++) begin
            exp_data[i] = 'h11111111 * i;
        end
        // Write values to register array
        for (int i = 0; i < COUNT_RW_ARRAY_EXAMPLE; i++) begin
            reg_blk_agent.write_rw_array_example(i, exp_data[i]);
        end
        // Read values back
        for (int i = 0; i < COUNT_RW_ARRAY_EXAMPLE; i++) begin
            reg_blk_agent.read_rw_array_example(i, got_data[i]);
        end
        
        // Check got against expected:
        for (int i = 0; i < COUNT_RW_ARRAY_EXAMPLE; i++) begin
            `FAIL_UNLESS(got_data[i] == exp_data[i]);
        end

    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
