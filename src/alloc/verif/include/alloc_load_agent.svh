class alloc_load_agent #(
    parameter int BUFFER_SIZE = 1,
    parameter int PTR_WID = 1,
    parameter int META_WID = 1
) extends std_verif_pkg::agent;

    //===================================
    // Geometry and virtual interface
    //===================================
    localparam int SIZE_WID = $clog2(BUFFER_SIZE);

    virtual alloc_intf #(
        .BUFFER_SIZE(BUFFER_SIZE), .PTR_WID(PTR_WID), .META_WID(META_WID)
    ) alloc_vif;

    //===================================
    // Construction and idle control
    //===================================
    function new(input string name="alloc_load_agent");
        super.new(name);
        this.alloc_vif = null;
    endfunction

    virtual protected task _idle();
        alloc_vif.cb_load.req <= 1'b0;
        alloc_vif.cb_load.ack <= 1'b0;
        alloc_vif.cb_load.ptr <= '0;
        @(alloc_vif.cb_load);
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(alloc_vif.cb_load);
    endtask

    //===================================
    // Load requests and descriptor transfers
    //===================================
    task load_req(input bit [PTR_WID-1:0] ptr);
        alloc_vif.cb_load.req <= 1'b1;
        alloc_vif.cb_load.ptr <= ptr;
        @(alloc_vif.cb_load iff (alloc_vif.cb_load.mon_req && alloc_vif.cb_load.rdy));
        alloc_vif.cb_load.req <= 1'b0;
    endtask

    task load(
            output bit [PTR_WID-1:0] ptr,
            output bit eof,
            output bit [SIZE_WID-1:0] size,
            output bit [META_WID-1:0] meta,
            output bit err
        );
        alloc_vif.cb_load.ack <= 1'b1;
        @(alloc_vif.cb_load iff (alloc_vif.cb_load.vld && alloc_vif.cb_load.mon_ack));
        ptr = alloc_vif.cb_load.nxt_ptr;
        eof = alloc_vif.cb_load.eof;
        size = alloc_vif.cb_load.size;
        meta = alloc_vif.cb_load.meta;
        err = alloc_vif.cb_load.err;
        alloc_vif.cb_load.ack <= 1'b0;
    endtask

endclass : alloc_load_agent
