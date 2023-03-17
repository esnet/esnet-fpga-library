interface db_intf #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[31:0]
) (
    input logic clk
);
    // Signals
    logic     req;
    KEY_T     key;
    logic     rdy;
    logic     ack;
    logic     error;

    logic     valid; 
    VALUE_T   value;


    logic     next; // Iterator over raw entries; when next is asserted,
                    // key is ignored and the entry is read from the next
                    // physical storage slot
    KEY_T     next_key; // Key found in 'next' physical storage slot is reported in next_key

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
        default input #1step output #1step;
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
            input KEY_T _key
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
            output VALUE_T _value,
            output bit _error
        );
        wait_ack(_error);
        _valid = cb.valid;
        _value = cb.value;
    endtask

    task _query(
            input KEY_T _key,
            output bit _valid,
            output VALUE_T _value,
            output bit _error
        );
        send(_key);
        receive(_valid, _value, _error);
    endtask

    task query(
            input KEY_T _key,
            output bit _valid,
            output VALUE_T _value,
            output bit _error,
            output bit _timeout,
            input int TIMEOUT=64
        );
        fork
            begin
                fork
                    begin
                        _query(_key, _valid, _value, _error);
                    end
                    begin
                        _timeout = 1'b0;
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            _timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
    endtask

    task _post_update(
            input KEY_T _key,
            input bit _valid,
            input VALUE_T _value
        );
        cb.valid <= _valid;
        cb.value <= _value;
        cb.next <= 1'b0;
        send(_key);
    endtask

    task post_update(
            input KEY_T _key,
            input bit _valid,
            input VALUE_T _value,
            output bit _timeout,
            input int TIMEOUT=64
        );
        fork
            begin
                fork
                    begin
                        _post_update(_key, _valid, _value);
                    end
                    begin
                        _timeout = 1'b0;
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            _timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
    endtask

    task _update(
            input KEY_T _key,
            input bit _valid,
            input VALUE_T _value,
            output bit _error
        );
        _post_update(_key, _valid, _value);
        wait_ack(_error);
    endtask

    task update(
            input KEY_T _key,
            input bit _valid,
            input VALUE_T _value,
            output bit _error,
            output bit _timeout,
            input int TIMEOUT=64
        );
        fork
            begin
                fork
                    begin
                        _update(_key, _valid, _value, _error);
                    end
                    begin
                        _timeout = 1'b0;
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            _timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
    endtask

    task wait_ready(
            output bit timeout,
            input int TIMEOUT=32
        );
        timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        wait(cb.rdy);
                    end
                    begin
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
    endtask

endinterface : db_intf


// DB interface requester termination helper module
module db_intf_requester_term (
    db_intf.requester db_if
);
    // Tie off requester outputs
    assign db_if.req = 1'b0;
    assign db_if.key = '0;
    assign db_if.next = 1'b0;

endmodule : db_intf_requester_term


// DB interface responder termination helper module
module db_intf_responder_term (
    db_intf.responder db_if
);
    // Tie off responder outputs
    assign db_if.rdy = 1'b0;
    assign db_if.ack = 1'b0;
    assign db_if.error = 1'b0;

endmodule : db_intf_responder_term

// DB interface connector helper module
// - can connect either read interfaces or write interfaces
module db_intf_connector #(
    parameter bit WR_RD_N = 1'b0
) (
    db_intf.responder db_if_from_requester,
    db_intf.requester db_if_to_responder
);

    assign db_if_to_responder.req = db_if_from_requester.req;
    assign db_if_to_responder.key = db_if_from_requester.key;
    assign db_if_to_responder.next = db_if_from_requester.next;

    assign db_if_from_requester.rdy = db_if_to_responder.rdy;
    assign db_if_from_requester.ack = db_if_to_responder.ack;
    assign db_if_from_requester.error = db_if_to_responder.error;
    assign db_if_from_requester.next_key = db_if_to_responder.next_key;

    // Connect valid/value inout ports according to specified direction
    generate
        if (WR_RD_N) begin : g__wr
            assign db_if_to_responder.valid = db_if_from_requester.valid;
            assign db_if_to_responder.value = db_if_from_requester.value;
        end : g__wr
        else begin : g__rd
            assign db_if_from_requester.valid = db_if_to_responder.valid;
            assign db_if_from_requester.value = db_if_to_responder.value;
        end : g__rd
    endgenerate
endmodule


// DB interface connector for write interfaces
module db_intf_wr_connector #(
) (
    db_intf.responder db_if_from_requester,
    db_intf.requester db_if_to_responder
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
    db_intf.responder db_if_from_requester,
    db_intf.requester db_if_to_responder
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
    parameter int NUM_IFS = 2,
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  NUM_TRANSACTIONS = 32,
    parameter bit  WR_RD_N = 1'b0
) (
    input logic        clk,
    input logic        srst,
    input int          mux_sel,
    db_intf.responder  db_if_from_requester [NUM_IFS],
    db_intf.requester  db_if_to_responder
);
    generate
        if (NUM_IFS > 1) begin : g__mux
            // (Local) Parameters
            localparam int MUX_SEL_WID = $clog2(NUM_IFS);

            // (Local) Typedefs
            typedef logic [MUX_SEL_WID-1:0] mux_sel_t;

            // (Local) Signals
            mux_sel_t __mux_sel;
            mux_sel_t __demux_sel;

            logic   db_if_from_requester_rdy      [NUM_IFS];
            logic   db_if_from_requester_req      [NUM_IFS];
            KEY_T   db_if_from_requester_key      [NUM_IFS];
            logic   db_if_from_requester_next     [NUM_IFS];
            logic   db_if_from_requester_ack      [NUM_IFS];
            logic   db_if_from_requester_error    [NUM_IFS];

            // Convert between array of signals and array of interfaces
            for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                assign db_if_from_requester[g_if].rdy   = db_if_from_requester_rdy[g_if];
                assign db_if_from_requester[g_if].ack   = db_if_from_requester_ack[g_if];
                assign db_if_from_requester[g_if].error = db_if_from_requester_error[g_if];
                assign db_if_from_requester_req[g_if]  = db_if_from_requester[g_if].req;
                assign db_if_from_requester_key[g_if]  = db_if_from_requester[g_if].key;
                assign db_if_from_requester_next[g_if] = db_if_from_requester[g_if].next;
                assign db_if_from_requester[g_if].next_key = db_if_to_responder.next_key;
            end : g__if

            // Mux requests
            assign __mux_sel = mux_sel[MUX_SEL_WID-1:0] % NUM_IFS;

            always_comb begin
                db_if_to_responder.req  = db_if_from_requester_req [__mux_sel];
                db_if_to_responder.key  = db_if_from_requester_key [__mux_sel];
                db_if_to_responder.next = db_if_from_requester_next[__mux_sel];
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == __mux_sel) db_if_from_requester_rdy[i] = db_if_to_responder.rdy;
                    else                db_if_from_requester_rdy[i] = 1'b0;
                end
            end

            // Maintain context for open transactions
            fifo_small   #(
                .DATA_T  ( mux_sel_t ),
                .DEPTH   ( NUM_TRANSACTIONS )
            ) i_fifo_small__ctxt (
                .clk     ( clk ),
                .srst    ( srst ),
                .wr      ( db_if_to_responder.req && db_if_to_responder.rdy ),
                .wr_data ( __mux_sel ),
                .full    ( ),
                .oflow   ( ),
                .rd      ( db_if_to_responder.ack ),
                .rd_data ( __demux_sel ),
                .empty   ( ),
                .uflow   ( )
            );

            // Demux responses
            always_comb begin
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == __demux_sel) begin
                        db_if_from_requester_ack[i] = db_if_to_responder.ack;
                        db_if_from_requester_error[i] = db_if_to_responder.error;
                    end else begin
                        db_if_from_requester_ack[i] = 1'b0;
                        db_if_from_requester_error[i] = 1'b0;
                    end
                end
            end

            // Connect valid/value inout ports according to specified direction
            if (WR_RD_N) begin : g__wr
                // (Local) signals
                logic   db_if_from_requester_valid [NUM_IFS];
                VALUE_T db_if_from_requester_value [NUM_IFS];
                // Convert between array of signals and array of interfaces
                for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                    assign db_if_from_requester_valid[g_if] = db_if_from_requester[g_if].valid;
                    assign db_if_from_requester_value[g_if] = db_if_from_requester[g_if].value;
                end : g__if
                always_comb begin
                    db_if_to_responder.valid = db_if_from_requester_valid[__mux_sel];
                    db_if_to_responder.value = db_if_from_requester_value[__mux_sel];
                end
            end : g__wr
            else begin : g__rd
                for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                    assign db_if_from_requester[g_if].valid = db_if_to_responder.valid;
                    assign db_if_from_requester[g_if].value = db_if_to_responder.value;
                end : g__if
            end : g__rd

        end : g__mux
        else begin : g__connector
            // Single interface, no mux required
            db_intf_connector #(
                .WR_RD_N ( WR_RD_N )
            ) i_db_intf_connector (
                .db_if_from_requester ( db_if_from_requester[0] ),
                .db_if_to_responder   ( db_if_to_responder )
            );
        end : g__connector
    endgenerate

endmodule : db_intf_mux


// Database interface 2:1 mux component
// (built using db_intf_mux as a basis but provides
//  simplified interface for most common mux configuration)
module db_intf_2to1_mux #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  NUM_TRANSACTIONS = 32,
    parameter bit  WR_RD_N = 1'b0
) (
    input logic clk,
    input logic srst,
    input logic mux_sel,
    db_intf.responder db_if_from_requester_0,
    db_intf.responder db_if_from_requester_1,
    db_intf.requester db_if_to_responder
);
    // Interfaces
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) db_if_from_requester [2] (.clk(clk));

    db_intf_connector #(
        .WR_RD_N ( WR_RD_N )
    ) i_db_intf_connector__hi_prio (
        .db_if_from_requester ( db_if_from_requester_0 ),
        .db_if_to_responder   ( db_if_from_requester[0] )
    );

    db_intf_connector #(
        .WR_RD_N ( WR_RD_N )
    ) i_db_intf_connector__lo_prio (
        .db_if_from_requester ( db_if_from_requester_1 ),
        .db_if_to_responder   ( db_if_from_requester[1] )
    );

    // Mux
    db_intf_mux          #(
        .KEY_T            ( KEY_T ),
        .VALUE_T          ( VALUE_T ),
        .NUM_IFS          ( 2 ),
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( WR_RD_N )
    ) i_db_intf_mux (
        .clk ( clk ),
        .srst ( srst ),
        .mux_sel ( {31'b0, mux_sel} ),
        .db_if_from_requester ( db_if_from_requester ),
        .db_if_to_responder ( db_if_to_responder )
    );

endmodule : db_intf_2to1_mux


// Database interface priority mux component
// - muxes between two database interfaces, with strict
//   priority granted to the hi_prio interface
// - can mux either read interfaces or write interfaces
module db_intf_prio_mux #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  NUM_TRANSACTIONS = 32,
    parameter bit  WR_RD_N = 1'b0
) (
    input logic clk,
    input logic srst,
    db_intf.responder db_if_from_requester_hi_prio,
    db_intf.responder db_if_from_requester_lo_prio,
    db_intf.requester db_if_to_responder
);
    // Signals
    logic mux_sel;

    // Interfaces
    db_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) __db_if_from_requester_hi_prio (.clk(clk));

    // Priority select
    assign mux_sel = db_if_from_requester_hi_prio.req ? 0 : 1;

    // Mux
    db_intf_2to1_mux     #(
        .KEY_T            ( KEY_T ),
        .VALUE_T          ( VALUE_T ),
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( WR_RD_N )
    ) i_db_intf_2to1_mux  (
        .clk ( clk ),
        .srst ( srst ),
        .mux_sel ( mux_sel ),
        .db_if_from_requester_0 ( __db_if_from_requester_hi_prio ),
        .db_if_from_requester_1 ( db_if_from_requester_lo_prio ),
        .db_if_to_responder ( db_if_to_responder )
    );

    // Drive hi prio ready signal directly to avoid timing loop
    assign db_if_from_requester_hi_prio.rdy = db_if_to_responder.rdy;

    // Connect remainder of hi prio interface signals
    assign __db_if_from_requester_hi_prio.req = db_if_from_requester_hi_prio.req;
    assign __db_if_from_requester_hi_prio.key = db_if_from_requester_hi_prio.key;
    assign __db_if_from_requester_hi_prio.next = db_if_from_requester_hi_prio.next;
    assign db_if_from_requester_hi_prio.ack = __db_if_from_requester_hi_prio.ack;
    assign db_if_from_requester_hi_prio.error = __db_if_from_requester_hi_prio.error;
    assign db_if_from_requester_hi_prio.next_key = __db_if_from_requester_hi_prio.next_key;

    // Connect valid/value inout ports according to specified direction
    generate
        if (WR_RD_N) begin : g__wr
            assign __db_if_from_requester_hi_prio.valid = db_if_from_requester_hi_prio.valid;
            assign __db_if_from_requester_hi_prio.value = db_if_from_requester_hi_prio.value;
        end : g__wr
        else begin : g__rd
            assign db_if_from_requester_hi_prio.valid = __db_if_from_requester_hi_prio.valid;
            assign db_if_from_requester_hi_prio.value = __db_if_from_requester_hi_prio.value;
        end : g__rd
    endgenerate

endmodule : db_intf_prio_mux

// Priority mux for write interfaces
module db_intf_prio_wr_mux #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  NUM_TRANSACTIONS = 32
) (
    input logic clk,
    input logic srst,
    db_intf.responder db_if_from_requester_hi_prio,
    db_intf.responder db_if_from_requester_lo_prio,
    db_intf.requester db_if_to_responder
);
    db_intf_prio_mux     #(
        .KEY_T            ( KEY_T ),
        .VALUE_T          ( VALUE_T ),
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( 1 )
    ) i_db_intf_prio_mux  (
        .*
    );

endmodule : db_intf_prio_wr_mux

// Priority mux for read interfaces
module db_intf_prio_rd_mux #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  NUM_TRANSACTIONS = 32
) (
    input logic clk,
    input logic srst,
    db_intf.responder db_if_from_requester_hi_prio,
    db_intf.responder db_if_from_requester_lo_prio,
    db_intf.requester db_if_to_responder
);
    db_intf_prio_mux     #(
        .KEY_T            ( KEY_T ),
        .VALUE_T          ( VALUE_T ),
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
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  NUM_TRANSACTIONS = 32,
    parameter bit  WR_RD_N = 1'b0
) (
    input logic        clk,
    input logic        srst,
    input int          demux_sel,
    db_intf.responder  db_if_from_requester,
    db_intf.requester  db_if_to_responder [NUM_IFS]
);
    generate
        if (NUM_IFS > 1) begin : g__demux
            // (Local) Parameters
            localparam int MUX_SEL_WID = $clog2(NUM_IFS);

            // (Local) Typedefs
            typedef logic [MUX_SEL_WID-1:0] mux_sel_t;

            // (Local) Signals
            mux_sel_t __demux_sel;
            mux_sel_t __mux_sel;

            logic   db_if_to_responder_rdy      [NUM_IFS];
            logic   db_if_to_responder_req      [NUM_IFS];
            logic   db_if_to_responder_ack      [NUM_IFS];
            logic   db_if_to_responder_error    [NUM_IFS];
            KEY_T   db_if_to_responder_next_key [NUM_IFS];

            // Convert between array of signals and array of interfaces
            for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                assign db_if_to_responder_rdy[g_if] = db_if_to_responder[g_if].rdy;
                assign db_if_to_responder_ack[g_if] = db_if_to_responder[g_if].ack;
                assign db_if_to_responder_error[g_if] = db_if_to_responder[g_if].error;
                assign db_if_to_responder_next_key[g_if] = db_if_to_responder[g_if].next_key;
                assign db_if_to_responder[g_if].req = db_if_to_responder_req[g_if];
                assign db_if_to_responder[g_if].key = db_if_from_requester.key;
            end : g__if

            // Demux requests
            assign __demux_sel = demux_sel[MUX_SEL_WID-1:0] % NUM_IFS;

            always_comb begin
                db_if_from_requester.rdy = db_if_to_responder_rdy[__demux_sel];
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == __demux_sel) db_if_to_responder_req[i] = db_if_from_requester.req;
                    else                  db_if_to_responder_req[i] = 1'b0;
                end
            end

            // Maintain context for open transactions
            fifo_small  #(
                .DATA_T  ( mux_sel_t ),
                .DEPTH   ( NUM_TRANSACTIONS )
            ) i_fifo_sync__ctxt (
                .clk     ( clk ),
                .srst    ( srst ),
                .wr      ( db_if_from_requester.req && db_if_from_requester.rdy ),
                .wr_data ( __demux_sel ),
                .full    ( ),
                .oflow   ( ),
                .rd      ( db_if_from_requester.ack ),
                .rd_data ( __mux_sel ),
                .empty   ( ),
                .uflow   ( )
            );

            // Demux responses
            always_comb begin
                db_if_from_requester.ack = db_if_to_responder_ack[__mux_sel];
                db_if_from_requester.error = db_if_to_responder_error[__mux_sel];
                db_if_from_requester.next_key = db_if_to_responder_next_key[__mux_sel];
            end

            // Connect valid/value inout ports according to specified direction
            if (WR_RD_N) begin : g__wr
                for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                    assign db_if_to_responder[g_if].valid = db_if_from_requester.valid;
                    assign db_if_to_responder[g_if].value = db_if_from_requester.value;
                end
            end : g__wr
            else begin : g__rd
                // (Local) signals
                logic   db_if_to_responder_valid [NUM_IFS];
                VALUE_T db_if_to_responder_value [NUM_IFS];
                // Convert between array of signals and array of interfaces
                for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                    assign db_if_to_responder_valid[g_if] = db_if_to_responder[g_if].valid;
                    assign db_if_to_responder_value[g_if] = db_if_to_responder[g_if].value;
                end : g__if
                always_comb begin
                    db_if_from_requester.valid = db_if_to_responder_valid[__mux_sel];
                    db_if_from_requester.value = db_if_to_responder_value[__mux_sel];
                end
            end : g__rd
        end : g__demux
        else begin : g__connector
            // Single interface, no mux required
            db_intf_connector #(
                .WR_RD_N ( WR_RD_N )
            ) i_db_intf_connector (
                .db_if_from_requester ( db_if_from_requester ),
                .db_if_to_responder   ( db_if_to_responder[0] )
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
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  NUM_TRANSACTIONS = 32,
    parameter bit  WR_RD_N = 1'b0
) (
    input logic        clk,
    input logic        srst,
    db_intf.responder  db_if_from_requester,
    db_intf.requester  db_if_to_responder [NUM_IFS]
);

    int unsigned demux_sel;

    initial demux_sel = 0;
    always @(posedge clk) if (db_if_from_requester.req && db_if_from_requester.rdy) demux_sel <= demux_sel + 1;

    // Base demux component
    db_intf_demux        #(
        .NUM_IFS          ( NUM_IFS ),
        .KEY_T            ( KEY_T ),
        .VALUE_T          ( VALUE_T ),
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( WR_RD_N )
    ) i_db_intf_demux (
        .clk ( clk ),
        .srst ( srst ),
        .demux_sel ( demux_sel ),
        .db_if_from_requester ( db_if_from_requester ),
        .db_if_to_responder ( db_if_to_responder )
    );

endmodule : db_intf_rr_demux


// Round-robin demux for read interfaces
module db_intf_rr_rd_demux #(
    parameter int  NUM_IFS = 2,
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  NUM_TRANSACTIONS = 32
) (
    input logic clk,
    input logic srst,
    db_intf.responder db_if_from_requester,
    db_intf.requester db_if_to_responder [NUM_IFS]
);
    db_intf_rr_demux #(
        .NUM_IFS          ( NUM_IFS ),
        .KEY_T            ( KEY_T ),
        .VALUE_T          ( VALUE_T ),
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( 0 )
    ) i_db_intf_rr_demux (
        .*
    );

endmodule : db_intf_rr_rd_demux


// Round-robin demux for write interfaces
module db_intf_rr_wr_demux #(
    parameter int  NUM_IFS = 2,
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0],
    parameter int  NUM_TRANSACTIONS = 32
) (
    input logic clk,
    input logic srst,
    db_intf.responder db_if_from_requester,
    db_intf.requester db_if_to_responder [NUM_IFS]
);
    db_intf_rr_demux #(
        .NUM_IFS          ( NUM_IFS ),
        .KEY_T            ( KEY_T ),
        .VALUE_T          ( VALUE_T ),
        .NUM_TRANSACTIONS ( NUM_TRANSACTIONS ),
        .WR_RD_N          ( 1 )
    ) i_db_intf_rr_demux (
        .*
    );

endmodule : db_intf_rr_wr_demux

