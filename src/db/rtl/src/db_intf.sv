interface db_intf #(
    parameter int KEY_WID = 1,
    parameter int VALUE_WID = 1
) (
    input logic clk
);
    // Signals
    logic                 req;
    logic [KEY_WID-1:0]   key;
    logic                 rdy;
    logic                 ack;
    logic                 error;

    logic                 valid;
    logic [VALUE_WID-1:0] value;


    logic                 next; // Iterator over raw entries; when next is asserted,
                                // key is ignored and the entry is read from the next
                                // physical storage slot
    logic [KEY_WID-1:0]   next_key; // Key found in 'next' physical storage slot is reported in next_key

    modport requester(
        input  clk,
        input  rdy,
        output req,
        input  ack,
        input  error,
        output key,
        output next,
        inout  valid, // Input for query interface, output for update interface
        inout  value, // Input for query interface, output for update interface
        input  next_key
    );

    modport responder(
        input  clk,
        output rdy,
        input  req,
        output ack,
        output error,
        input  key,
        input  next,
        inout  valid, // Output for query interface, input for update interface
        inout  value, // Output for query interface, input for update interface
        output next_key
    );

    clocking cb @(posedge clk);
        output key, next;
        input rdy, ack, error, next_key;
        inout req, valid, value;
    endclocking

    task _wait(input int cycles);
        repeat(cycles) @(cb);
    endtask

    task idle();
        cb.req <= 1'b0;
    endtask

    task send(
            input bit [KEY_WID-1:0] _key
        );
        cb.req <= 1'b1;
        cb.key <= _key;
        cb.next <= 1'b0;
        @(cb);
        wait (cb.req && cb.rdy);
        cb.req <= 1'b0;
    endtask

    task wait_ack(
            output bit _error
        );
        @(cb);
        wait(cb.ack);
        _error = cb.error;
    endtask

    task receive(
            output bit _valid,
            output bit [VALUE_WID-1:0] _value,
            output bit _error
        );
        wait_ack(_error);
        _valid = cb.valid;
        _value = cb.value;
    endtask

    task _query(
            input bit [KEY_WID-1:0] _key,
            output bit _valid,
            output bit [VALUE_WID-1:0] _value,
            output bit _error
        );
        send(_key);
        receive(_valid, _value, _error);
    endtask

    task query(
            input bit [KEY_WID-1:0] _key,
            output bit _valid,
            output bit [VALUE_WID-1:0] _value,
            output bit _error,
            output bit _timeout,
            input int TIMEOUT=64
        );
        automatic bit __timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        _query(_key, _valid, _value, _error);
                    end
                    begin
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            __timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        _timeout = __timeout;
    endtask

    task _post_update(
            input bit [KEY_WID-1:0] _key,
            input bit _valid,
            input bit [VALUE_WID-1:0] _value
        );
        cb.valid <= _valid;
        cb.value <= _value;
        cb.next <= 1'b0;
        send(_key);
    endtask

    task post_update(
            input bit [KEY_WID-1:0] _key,
            input bit _valid,
            input bit [VALUE_WID-1:0] _value,
            output bit _timeout,
            input int TIMEOUT=64
        );
        automatic bit __timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        _post_update(_key, _valid, _value);
                    end
                    begin
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            __timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        _timeout = __timeout;
    endtask

    task _update(
            input bit [KEY_WID-1:0] _key,
            input bit _valid,
            input bit [VALUE_WID-1:0] _value,
            output bit _error
        );
        _post_update(_key, _valid, _value);
        wait_ack(_error);
    endtask

    task update(
            input bit [KEY_WID-1:0] _key,
            input bit _valid,
            input bit [VALUE_WID-1:0] _value,
            output bit _error,
            output bit _timeout,
            input int TIMEOUT=64
        );
        automatic bit __timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        _update(_key, _valid, _value, _error);
                    end
                    begin
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            __timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        _timeout = __timeout;
    endtask

    task wait_ready(
            output bit timeout,
            input int TIMEOUT=32
        );
        automatic bit _timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        wait(cb.rdy);
                    end
                    begin
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            _timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        timeout = _timeout;
    endtask

endinterface : db_intf


// DB interface requester termination helper module
module db_intf_requester_term (
    db_intf.requester to_responder
);
    // Tie off requester outputs
    assign to_responder.req = 1'b0;
    assign to_responder.key = '0;
    assign to_responder.next = 1'b0;

endmodule : db_intf_requester_term


// DB interface responder termination helper module
module db_intf_responder_term (
    db_intf.responder from_requester
);
    // Tie off responder outputs
    assign from_requester.rdy = 1'b0;
    assign from_requester.ack = 1'b0;
    assign from_requester.error = 1'b0;

endmodule : db_intf_responder_term

// DB interface connector helper module
// - can connect either read interfaces or write interfaces
module db_intf_connector #(
    parameter bit WR_RD_N = 1'b0
) (
    db_intf.responder from_requester,
    db_intf.requester to_responder
);
    // Parameter check
    initial begin
        std_pkg::param_check(from_requester.KEY_WID,   to_responder.KEY_WID,   "KEY_WID");
        std_pkg::param_check(from_requester.VALUE_WID, to_responder.VALUE_WID, "VALUE_WID");
    end

    assign to_responder.req = from_requester.req;
    assign to_responder.key = from_requester.key;
    assign to_responder.next = from_requester.next;

    assign from_requester.rdy = to_responder.rdy;
    assign from_requester.ack = to_responder.ack;
    assign from_requester.error = to_responder.error;
    assign from_requester.next_key = to_responder.next_key;

    // Connect valid/value inout ports according to specified direction
    generate
        if (WR_RD_N) begin : g__wr
            assign to_responder.valid = from_requester.valid;
            assign to_responder.value = from_requester.value;
        end : g__wr
        else begin : g__rd
            assign from_requester.valid = to_responder.valid;
            assign from_requester.value = to_responder.value;
        end : g__rd
    endgenerate
endmodule


// DB interface connector for write interfaces
module db_intf_wr_connector #(
) (
    db_intf.responder from_requester,
    db_intf.requester to_responder
);
    db_intf_connector #(
        .WR_RD_N ( 1 )
    ) i_db_intf_connector (
        .*
    );

endmodule


// DB interface connector for read interfaces
module db_intf_rd_connector #(
) (
    db_intf.responder from_requester,
    db_intf.requester to_responder
);
    db_intf_connector #(
        .WR_RD_N ( 0 )
    ) i_db_intf_connector (
        .*
    );

endmodule


// Database interface static mux component
// - provides mux between NUM_IFS database interfaces
// - can mux either read interfaces or write interfaces
//   by setting WR_RD_N parameter appropriately
module db_intf_mux #(
    parameter int  NUM_IFS = 2,
    parameter int  NUM_TRANSACTIONS = 32,
    parameter bit  WR_RD_N = 1'b0,
    // Derived parameters (don't override)
    parameter int  SEL_WID = NUM_IFS > 1 ? $clog2(NUM_IFS) : 1
) (
    input logic               clk,
    input logic               srst,
    input logic [SEL_WID-1:0] mux_sel,
    db_intf.responder         from_requester [NUM_IFS],
    db_intf.requester         to_responder
);
    // Parameters
    localparam int KEY_WID = to_responder.KEY_WID;
    localparam int VALUE_WID = to_responder.VALUE_WID;

    localparam int NUM_IFS__POW2 = 2**SEL_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_requester[0].KEY_WID,   to_responder.KEY_WID,   "KEY_WID");
        std_pkg::param_check(from_requester[0].VALUE_WID, to_responder.VALUE_WID, "VALUE_WID");
    end

    generate
        if (NUM_IFS > 1) begin : g__mux
            // (Local) Signals
            logic [SEL_WID-1:0] demux_sel;

            logic               from_requester_rdy   [NUM_IFS];
            logic               from_requester_req   [NUM_IFS__POW2];
            logic [KEY_WID-1:0] from_requester_key   [NUM_IFS__POW2];
            logic               from_requester_next  [NUM_IFS__POW2];
            logic               from_requester_ack   [NUM_IFS];
            logic               from_requester_error [NUM_IFS];

            // Convert between array of signals and array of interfaces
            for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                assign from_requester[g_if].rdy   = from_requester_rdy[g_if];
                assign from_requester[g_if].ack   = from_requester_ack[g_if];
                assign from_requester[g_if].error = from_requester_error[g_if];
                assign from_requester_req[g_if]   = from_requester[g_if].req;
                assign from_requester_key[g_if]   = from_requester[g_if].key;
                assign from_requester_next[g_if]  = from_requester[g_if].next;
                assign from_requester[g_if].next_key = to_responder.next_key;
            end : g__if
            // Assign 'out-of-range' values
            for (genvar g_if = NUM_IFS; g_if < NUM_IFS__POW2; g_if++) begin : g__if_out_of_range
                assign from_requester_req[g_if] = 1'b0;
                assign from_requester_key[g_if] = '0;
                assign from_requester_next[g_if] = 1'b0;
            end : g__if_out_of_range

            always_comb begin
                to_responder.req  = from_requester_req [mux_sel];
                to_responder.key  = from_requester_key [mux_sel];
                to_responder.next = from_requester_next[mux_sel];
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == mux_sel) from_requester_rdy[i] = to_responder.rdy;
                    else              from_requester_rdy[i] = 1'b0;
                end
            end

            // Maintain context for open transactions
            fifo_small_ctxt #(
                .DATA_WID ( SEL_WID ),
                .DEPTH    ( NUM_TRANSACTIONS )
            ) i_fifo_small_ctxt (
                .clk     ( clk ),
                .srst    ( srst ),
                .wr_rdy  ( ),
                .wr      ( to_responder.req && to_responder.rdy ),
                .wr_data ( mux_sel ),
                .rd      ( to_responder.ack ),
                .rd_vld  ( ),
                .rd_data ( demux_sel ),
                .oflow   ( ),
                .uflow   ( )
            );

            // Demux responses
            always_comb begin
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == demux_sel) begin
                        from_requester_ack[i] = to_responder.ack;
                        from_requester_error[i] = to_responder.error;
                    end else begin
                        from_requester_ack[i] = 1'b0;
                        from_requester_error[i] = 1'b0;
                    end
                end
            end

            // Connect valid/value inout ports according to specified direction
            if (WR_RD_N) begin : g__wr
                // (Local) signals
                logic                 from_requester_valid [NUM_IFS__POW2];
                logic [VALUE_WID-1:0] from_requester_value [NUM_IFS__POW2];
                // Convert between array of signals and array of interfaces
                for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                    assign from_requester_valid[g_if] = from_requester[g_if].valid;
                    assign from_requester_value[g_if] = from_requester[g_if].value;
                end : g__if
                // Assign 'out-of-range' values
                for (genvar g_if = NUM_IFS; g_if < NUM_IFS__POW2; g_if++) begin : g__if_out_of_range
                    assign from_requester_valid[g_if] = 1'b0;
                    assign from_requester_value[g_if] = '0;
                end : g__if_out_of_range
                always_comb begin
                    to_responder.valid = from_requester_valid[mux_sel];
                    to_responder.value = from_requester_value[mux_sel];
                end
            end : g__wr
            else begin : g__rd
                for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                    assign from_requester[g_if].valid = to_responder.valid;
                    assign from_requester[g_if].value = to_responder.value;
                end : g__if
            end : g__rd

        end : g__mux
        else begin : g__connector
            // Single interface, no mux required
            db_intf_connector #(
                .WR_RD_N ( WR_RD_N )
            ) i_db_intf_connector (
                .from_requester ( from_requester[0] ),
                .to_responder
            );
        end : g__connector
    endgenerate

endmodule : db_intf_mux


// Database interface 2:1 mux component
// (built using db_intf_mux as a basis but provides
//  simplified interface for most common mux configuration)
module db_intf_2to1_mux #(
    parameter int NUM_TRANSACTIONS = 32,
    parameter bit WR_RD_N = 1'b0
) (
    input logic clk,
    input logic srst,
    input logic mux_sel,
    db_intf.responder from_requester_0,
    db_intf.responder from_requester_1,
    db_intf.requester to_responder
);
    // Parameters
    localparam int KEY_WID = to_responder.KEY_WID;
    localparam int VALUE_WID = to_responder.VALUE_WID;

    // Interfaces
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) from_requester [2] (.clk);

    db_intf_connector #(
        .WR_RD_N ( WR_RD_N )
    ) i_db_intf_connector__0 (
        .from_requester ( from_requester_0 ),
        .to_responder   ( from_requester[0] )
    );

    db_intf_connector #(
        .WR_RD_N ( WR_RD_N )
    ) i_db_intf_connector__1 (
        .from_requester ( from_requester_1 ),
        .to_responder   ( from_requester[1] )
    );

    // WORKAROUND-ELAB-HIER-DEPTH {
    //     Flatten hierarchy here to work around elaboration issues (as of Vivado 2024.2).
    //
    localparam int NUM_IFS = 2;
    localparam int SEL_WID = 1;
    generate
        if (NUM_IFS > 1) begin : g__mux
            // (Local) Signals
            logic [SEL_WID-1:0] demux_sel;

            logic               from_requester_rdy   [NUM_IFS];
            logic               from_requester_req   [NUM_IFS];
            logic [KEY_WID-1:0] from_requester_key   [NUM_IFS];
            logic               from_requester_next  [NUM_IFS];
            logic               from_requester_ack   [NUM_IFS];
            logic               from_requester_error [NUM_IFS];

            // Convert between array of signals and array of interfaces
            for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                assign from_requester[g_if].rdy   = from_requester_rdy[g_if];
                assign from_requester[g_if].ack   = from_requester_ack[g_if];
                assign from_requester[g_if].error = from_requester_error[g_if];
                assign from_requester_req[g_if]   = from_requester[g_if].req;
                assign from_requester_key[g_if]   = from_requester[g_if].key;
                assign from_requester_next[g_if]  = from_requester[g_if].next;
                assign from_requester[g_if].next_key = to_responder.next_key;
            end : g__if

            always_comb begin
                to_responder.req  = from_requester_req [mux_sel];
                to_responder.key  = from_requester_key [mux_sel];
                to_responder.next = from_requester_next[mux_sel];
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == mux_sel) from_requester_rdy[i] = to_responder.rdy;
                    else              from_requester_rdy[i] = 1'b0;
                end
            end

            // Maintain context for open transactions
            fifo_small_ctxt #(
                .DATA_WID ( SEL_WID ),
                .DEPTH    ( NUM_TRANSACTIONS )
            ) i_fifo_small_ctxt (
                .clk     ( clk ),
                .srst    ( srst ),
                .wr_rdy  ( ),
                .wr      ( to_responder.req && to_responder.rdy ),
                .wr_data ( mux_sel ),
                .rd      ( to_responder.ack ),
                .rd_vld  ( ),
                .rd_data ( demux_sel ),
                .oflow   ( ),
                .uflow   ( )
            );

            // Demux responses
            always_comb begin
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == demux_sel) begin
                        from_requester_ack[i] = to_responder.ack;
                        from_requester_error[i] = to_responder.error;
                    end else begin
                        from_requester_ack[i] = 1'b0;
                        from_requester_error[i] = 1'b0;
                    end
                end
            end

            // Connect valid/value inout ports according to specified direction
            if (WR_RD_N) begin : g__wr
                // (Local) signals
                logic                 from_requester_valid   [NUM_IFS];
                logic [VALUE_WID-1:0] from_requester_value [NUM_IFS];
                // Convert between array of signals and array of interfaces
                for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                    assign from_requester_valid[g_if] = from_requester[g_if].valid;
                    assign from_requester_value[g_if] = from_requester[g_if].value;
                end : g__if
                always_comb begin
                    to_responder.valid = from_requester_valid[mux_sel];
                    to_responder.value = from_requester_value[mux_sel];
                end
            end : g__wr
            else begin : g__rd
                for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                    assign from_requester[g_if].valid = to_responder.valid;
                    assign from_requester[g_if].value = to_responder.value;
                end : g__if
            end : g__rd

        end : g__mux
        else begin : g__connector
            // Single interface, no mux required
            db_intf_connector #(
                .WR_RD_N ( WR_RD_N )
            ) i_db_intf_connector (
                .from_requester ( from_requester[0] ),
                .to_responder
            );
        end : g__connector
    endgenerate
    // db_intf_mux #(
    //     .NUM_IFS ( 2 ),
    //     .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
    //     .WR_RD_N ( WR_RD_N )
    // ) i_db_intf_mux (.*);
    // } WORKAROUND-ELAB-HIER-DEPTH
endmodule : db_intf_2to1_mux


// Database interface priority mux component
// - muxes between two database interfaces, with strict
//   priority granted to the hi_prio interface
// - can mux either read interfaces or write interfaces
module db_intf_prio_mux #(
    parameter int  NUM_TRANSACTIONS = 32,
    parameter bit  WR_RD_N = 1'b0
) (
    input logic clk,
    input logic srst,
    db_intf.responder from_requester_hi_prio,
    db_intf.responder from_requester_lo_prio,
    db_intf.requester to_responder
);
    // Parameters
    localparam int KEY_WID = to_responder.KEY_WID;
    localparam int VALUE_WID = to_responder.VALUE_WID;

    // Signals
    logic mux_sel;

    // Interfaces
    db_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) __from_requester_hi_prio (.clk);

    // Priority select
    assign mux_sel = from_requester_hi_prio.req ? 1'b0 : 1'b1;

    // Mux
    db_intf_2to1_mux     #(
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( WR_RD_N )
    ) i_db_intf_2to1_mux  (
        .clk ( clk ),
        .srst ( srst ),
        .mux_sel ( mux_sel ),
        .from_requester_0 ( __from_requester_hi_prio ),
        .from_requester_1 ( from_requester_lo_prio ),
        .to_responder
    );

    // Drive hi prio ready signal directly to avoid timing loop
    assign from_requester_hi_prio.rdy = to_responder.rdy;

    // Connect remainder of hi prio interface signals
    assign __from_requester_hi_prio.req = from_requester_hi_prio.req;
    assign __from_requester_hi_prio.key = from_requester_hi_prio.key;
    assign __from_requester_hi_prio.next = from_requester_hi_prio.next;
    assign from_requester_hi_prio.ack = __from_requester_hi_prio.ack;
    assign from_requester_hi_prio.error = __from_requester_hi_prio.error;
    assign from_requester_hi_prio.next_key = __from_requester_hi_prio.next_key;

    // Connect valid/value inout ports according to specified direction
    generate
        if (WR_RD_N) begin : g__wr
            assign __from_requester_hi_prio.valid = from_requester_hi_prio.valid;
            assign __from_requester_hi_prio.value = from_requester_hi_prio.value;
        end : g__wr
        else begin : g__rd
            assign from_requester_hi_prio.valid = __from_requester_hi_prio.valid;
            assign from_requester_hi_prio.value = __from_requester_hi_prio.value;
        end : g__rd
    endgenerate

endmodule : db_intf_prio_mux

// Priority mux for write interfaces
module db_intf_prio_wr_mux #(
    parameter int  NUM_TRANSACTIONS = 32
) (
    input logic clk,
    input logic srst,
    db_intf.responder from_requester_hi_prio,
    db_intf.responder from_requester_lo_prio,
    db_intf.requester to_responder
);
    db_intf_prio_mux     #(
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( 1 )
    ) i_db_intf_prio_mux  (
        .*
    );

endmodule : db_intf_prio_wr_mux

// Priority mux for read interfaces
module db_intf_prio_rd_mux #(
    parameter int  NUM_TRANSACTIONS = 32
) (
    input logic clk,
    input logic srst,
    db_intf.responder from_requester_hi_prio,
    db_intf.responder from_requester_lo_prio,
    db_intf.requester to_responder
);
    db_intf_prio_mux     #(
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( 0 )
    ) i_db_intf_prio_mux  (
        .*
    );

endmodule : db_intf_prio_rd_mux


// Database interface static demux component
// - provides demux to NUM_IFS database interfaces
// - can demux either read interfaces or write interfaces
//   by setting WR_RD_N parameter appropriately
module db_intf_demux #(
    parameter int  NUM_IFS = 2,
    parameter int  NUM_TRANSACTIONS = 32,
    parameter bit  WR_RD_N = 1'b0,
    // Derived parameters (don't override)
    parameter int  SEL_WID = NUM_IFS > 1 ?clog2(NUM_IFS) : 1
) (
    input logic               clk,
    input logic               srst,
    input logic [SEL_WID-1:0] demux_sel,
    db_intf.responder         from_requester,
    db_intf.requester         to_responder [NUM_IFS]
);
    // Parameters
    localparam int KEY_WID = from_requester.KEY_WID;
    localparam int VALUE_WID = from_requester.VALUE_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_requester.KEY_WID,   to_responder[0].KEY_WID,   "KEY_WID");
        std_pkg::param_check(from_requester.VALUE_WID, to_responder[0].VALUE_WID, "VALUE_WID");
    end

    generate
        if (NUM_IFS > 1) begin : g__demux
            // (Local) Signals
            logic [SEL_WID-1:0] mux_sel;

            logic                to_responder_rdy      [NUM_IFS];
            logic                to_responder_req      [NUM_IFS];
            logic                to_responder_ack      [NUM_IFS];
            logic                to_responder_error    [NUM_IFS];
            logic [KEY_WID-1:0]  to_responder_next_key [NUM_IFS];

            // Convert between array of signals and array of interfaces
            for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                assign to_responder_rdy[g_if] = to_responder[g_if].rdy;
                assign to_responder_ack[g_if] = to_responder[g_if].ack;
                assign to_responder_error[g_if] = to_responder[g_if].error;
                assign to_responder_next_key[g_if] = to_responder[g_if].next_key;
                assign to_responder[g_if].req = to_responder_req[g_if];
                assign to_responder[g_if].key = from_requester.key;
            end : g__if

            // Demux requests
            always_comb begin
                from_requester.rdy = to_responder_rdy[demux_sel];
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == demux_sel) to_responder_req[i] = from_requester.req;
                    else                to_responder_req[i] = 1'b0;
                end
            end

            // Maintain context for open transactions
            fifo_small_cxt #(
                .DATA_WID ( SEL_WID ),
                .DEPTH    ( NUM_TRANSACTIONS )
            ) i_fifo_small_ctxt (
                .clk     ( clk ),
                .srst    ( srst ),
                .wr_rdy  ( ),
                .wr      ( from_requester.req && from_requester.rdy ),
                .wr_data ( demux_sel ),
                .rd      ( from_requester.ack ),
                .rd_vld  ( ),
                .rd_data ( mux_sel ),
                .oflow   ( ),
                .uflow   ( )
            );

            // Demux responses
            always_comb begin
                from_requester.ack = to_responder_ack[mux_sel];
                from_requester.error = to_responder_error[mux_sel];
                from_requester.next_key = to_responder_next_key[mux_sel];
            end

            // Connect valid/value inout ports according to specified direction
            if (WR_RD_N) begin : g__wr
                for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                    assign to_responder[g_if].valid = from_requester.valid;
                    assign to_responder[g_if].value = from_requester.value;
                end
            end : g__wr
            else begin : g__rd
                // (Local) signals
                logic                 to_responder_valid [NUM_IFS];
                logic [VALUE_WID-1:0] to_responder_value [NUM_IFS];
                // Convert between array of signals and array of interfaces
                for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                    assign to_responder_valid[g_if] = to_responder[g_if].valid;
                    assign to_responder_value[g_if] = to_responder[g_if].value;
                end : g__if
                always_comb begin
                    from_requester.valid = to_responder_valid[mux_sel];
                    from_requester.value = to_responder_value[mux_sel];
                end
            end : g__rd
        end : g__demux
        else begin : g__connector
            // Single interface, no mux required
            db_intf_connector #(
                .WR_RD_N ( WR_RD_N )
            ) i_db_intf_connector (
                .from_requester,
                .to_responder ( to_responder[0] )
            );
        end : g__connector
    endgenerate

endmodule : db_intf_demux


// Database interface round-robin demux component
// - provides demux to NUM_IFS database interfaces
//   using round-bin distribution
// - can demux either read interfaces or write interfaces
//   by setting WR_RD_N parameter appropriately
module db_intf_rr_demux #(
    parameter int  NUM_IFS = 2,
    parameter int  NUM_TRANSACTIONS = 32,
    parameter bit  WR_RD_N = 1'b0
) (
    input logic        clk,
    input logic        srst,
    db_intf.responder  from_requester,
    db_intf.requester  to_responder [NUM_IFS]
);
    // Parameters
    localparam int SEL_WID = NUM_IFS > 1 ?clog2(NUM_IFS) : 1;

    // Signals
    logic [SEL_WID-1:0] demux_sel;

    initial demux_sel = 0;
    always @(posedge clk) if (from_requester.req && from_requester.rdy) demux_sel <= demux_sel + 1;

    // Base demux component
    db_intf_demux        #(
        .NUM_IFS          ( NUM_IFS ),
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( WR_RD_N )
    ) i_db_intf_demux (.*);

endmodule : db_intf_rr_demux


// Round-robin demux for read interfaces
module db_intf_rr_rd_demux #(
    parameter int  NUM_IFS = 2,
    parameter int  NUM_TRANSACTIONS = 32
) (
    input logic clk,
    input logic srst,
    db_intf.responder from_requester,
    db_intf.requester to_responder [NUM_IFS]
);
    db_intf_rr_demux #(
        .NUM_IFS          ( NUM_IFS ),
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( 0 )
    ) i_db_intf_rr_demux (
        .*
    );

endmodule : db_intf_rr_rd_demux


// Round-robin demux for write interfaces
module db_intf_rr_wr_demux #(
    parameter int  NUM_IFS = 2,
    parameter int  NUM_TRANSACTIONS = 32
) (
    input logic clk,
    input logic srst,
    db_intf.responder from_requester,
    db_intf.requester to_responder [NUM_IFS]
);
    db_intf_rr_demux #(
        .NUM_IFS          ( NUM_IFS ),
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( 1 )
    ) i_db_intf_rr_demux (
        .*
    );

endmodule : db_intf_rr_wr_demux

