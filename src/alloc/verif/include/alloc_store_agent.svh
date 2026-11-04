class alloc_store_agent #(
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
    function new(input string name="alloc_store_agent");
        super.new(name);
        this.alloc_vif = null;
    endfunction

    virtual protected task _idle();
        alloc_vif.cb_store.req <= 1'b0;
        alloc_vif.cb_store.vld <= 1'b0;
        alloc_vif.cb_store.nxt_ptr <= '0;
        alloc_vif.cb_store.eof <= 1'b0;
        alloc_vif.cb_store.size <= '0;
        alloc_vif.cb_store.meta <= '0;
        alloc_vif.cb_store.err <= 1'b0;
        @(alloc_vif.cb_store);
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(alloc_vif.cb_store);
    endtask

    //===================================
    // Store requests and descriptor transfers
    //===================================
    task store_req(output bit [PTR_WID-1:0] ptr);
        alloc_vif.cb_store.req <= 1'b1;
        @(alloc_vif.cb_store iff (alloc_vif.cb_store.mon_req && alloc_vif.cb_store.rdy));
        ptr = alloc_vif.cb_store.ptr;
        alloc_vif.cb_store.req <= 1'b0;
    endtask

    task store(
            input bit [PTR_WID-1:0] ptr,
            input bit eof=1'b0,
            input bit [SIZE_WID-1:0] size=0,
            input bit [META_WID-1:0] meta=0,
            input bit err=1'b0
        );
        alloc_vif.cb_store.vld <= 1'b1;
        alloc_vif.cb_store.nxt_ptr <= ptr;
        alloc_vif.cb_store.eof <= eof;
        alloc_vif.cb_store.size <= size;
        alloc_vif.cb_store.meta <= meta;
        alloc_vif.cb_store.err <= err;
        @(alloc_vif.cb_store iff (alloc_vif.cb_store.mon_vld && alloc_vif.cb_store.ack));
        alloc_vif.cb_store.vld <= 1'b0;
    endtask

endclass : alloc_store_agent
