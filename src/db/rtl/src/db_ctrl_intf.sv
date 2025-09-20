interface db_ctrl_intf #(
    parameter int KEY_WID   = 1,
    parameter int VALUE_WID = 1
) (
    input logic clk
);

    // Imports
    import db_pkg::*;

    // Signals
    // -- Controller to peripheral
    logic                 req;
    command_t             command;
    logic [KEY_WID-1:0]   key;
    logic [VALUE_WID-1:0] set_value;

    // -- Peripheral to controller
    logic                 rdy;
    logic                 ack;
    status_t              status;
    logic                 get_valid;
    logic [KEY_WID-1:0]   get_key;
    logic [VALUE_WID-1:0] get_value;

    modport controller(
        input  clk,
        output req,
        output command,
        output key,
        output set_value,
        input  rdy,
        input  ack,
        input  status,
        input  get_valid,
        input  get_key,
        input  get_value
    );

    modport peripheral(
        input  clk,
        input  req,
        input  command,
        input  key,
        input  set_value,
        output rdy,
        output ack,
        output status,
        output get_valid,
        output get_key,
        output get_value
    );

    clocking cb @(posedge clk);
        output command, key, set_value;
        input rdy, ack, status, get_valid, get_key, get_value;
        inout req;
    endclocking

    task _wait(input int cycles);
        repeat(cycles) @(cb);
    endtask

    task idle();
        cb.req <= 1'b0;
    endtask

    function automatic bit is_ready();
        return cb.rdy;
    endfunction

    task wait_ready(
            output bit _timeout,
            input int  TIMEOUT=0
        );
        automatic bit __timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        wait (cb.rdy);
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

    // Generic transaction (no timeout protection)
    task transact(
            input  command_t _command,
            output bit       _error
        );
        cb.command <= _command;
        cb.req <= 1'b1;
        wait (cb.req && cb.rdy);
        cb.req <= 1'b0;
        wait (cb.ack);
        _error = (cb.status != STATUS_OK);
    endtask

    // Drive key (for request)
    task _set_key(
            input bit [KEY_WID-1:0] _key
        );
        cb.key <= _key;
    endtask

    // Drive value (for request)
    task _set_value(
            input bit [VALUE_WID-1:0] _value
        );
        cb.set_value <= _value;
    endtask

    // Receive valid (for response)
    task _get_valid(
            output bit _valid
        );
        _valid = cb.get_valid;
    endtask

    // Receive valid (for response)
    task _get_key(
            output bit [KEY_WID-1:0] _key
        );
        _key = cb.get_key;
    endtask

    // Receive value (for response)
    task _get_value(
            output bit [VALUE_WID-1:0] _value
        );
        _value = cb.get_value;
    endtask

endinterface : db_ctrl_intf


module db_ctrl_intf_parameter_check (
    db_ctrl_intf from_controller,
    db_ctrl_intf to_peripheral
);
    initial begin
        std_pkg::param_check(from_controller.KEY_WID,   to_peripheral.KEY_WID,   "KEY_WID");
        std_pkg::param_check(from_controller.VALUE_WID, to_peripheral.VALUE_WID, "VALUE_WID");
    end
endmodule


// Database control interface controller termination helper module
module db_ctrl_intf_controller_term (
    db_ctrl_intf.controller to_peripheral
);
    // Tie off controller outputs
    assign to_peripheral.req = 1'b0;
    assign to_peripheral.command = db_pkg::COMMAND_NOP;

endmodule : db_ctrl_intf_controller_term


// Database control interface peripheral termination helper module
module db_ctrl_intf_peripheral_term (
    db_ctrl_intf.peripheral from_controller
);
    // Tie off peripheral outputs
    assign from_controller.rdy = 1'b0;
    assign from_controller.ack = 1'b0;
    assign from_controller.status = db_pkg::STATUS_UNSPECIFIED;

endmodule : db_ctrl_intf_peripheral_term


// Database control interface (back-to-back) connector helper module
module db_ctrl_intf_connector (
    db_ctrl_intf.peripheral from_controller,
    db_ctrl_intf.controller to_peripheral
);
    db_ctrl_intf_parameter_check param_check_0 (.*);

    // Connect signals (controller -> peripheral)
    assign to_peripheral.req = from_controller.req;
    assign to_peripheral.command = from_controller.command;
    assign to_peripheral.key = from_controller.key;
    assign to_peripheral.set_value = from_controller.set_value;

    // Connect signals (peripheral -> controller)
    assign from_controller.rdy = to_peripheral.rdy;
    assign from_controller.ack = to_peripheral.ack;
    assign from_controller.status = to_peripheral.status;
    assign from_controller.get_valid = to_peripheral.get_valid;
    assign from_controller.get_key = to_peripheral.get_key;
    assign from_controller.get_value = to_peripheral.get_value;

endmodule : db_ctrl_intf_connector


// Database control interface proxy stage
module db_ctrl_intf_proxy (
    input logic clk,
    input logic srst,
    db_ctrl_intf.peripheral from_controller,
    db_ctrl_intf.controller to_peripheral
);
    db_ctrl_intf_parameter_check param_check_0 (.*);

    // Signals
    logic pending;
    logic in_progress;

    // Proxy requests
    initial pending = 1'b0;
    always @(posedge clk) begin
        if (srst)                                            pending <= 1'b0;
        else if (from_controller.req && from_controller.rdy) pending <= 1'b1;
        else if (to_peripheral.rdy)                          pending <= 1'b0;
    end

    initial in_progress = 1'b0;
    always @(posedge clk) begin
        if (srst)                              in_progress <= 1'b0;
        else if (pending && to_peripheral.rdy) in_progress <= 1'b1;
        else if (to_peripheral.ack)            in_progress <= 1'b0;
    end

    assign to_peripheral.req = pending;
    assign from_controller.rdy = !pending && !in_progress;

    // Latch request context
    always_ff @(posedge clk) begin
        if (from_controller.req && from_controller.rdy) begin
            to_peripheral.command   <= from_controller.command;
            to_peripheral.key       <= from_controller.key;
            to_peripheral.set_value <= from_controller.set_value;
        end
    end

    // Pass response directly
    assign from_controller.ack       = to_peripheral.ack;
    assign from_controller.status    = to_peripheral.status;
    assign from_controller.get_valid = to_peripheral.get_valid;
    assign from_controller.get_key   = to_peripheral.get_key;
    assign from_controller.get_value = to_peripheral.get_value;

endmodule : db_ctrl_intf_proxy

// Database control interface static mux component
// - provides static (hard) mux between NUM_IFS control interfaces
module db_ctrl_intf_mux #(
    parameter int  NUM_IFS = 2,
    // Derived parameters (don't override)
    parameter int  SEL_WID = NUM_IFS > 1 ? $clog2(NUM_IFS) : 1
) (
    input logic               clk,
    input logic               srst,
    input logic [SEL_WID-1:0] mux_sel,
    db_ctrl_intf.peripheral   from_controller [NUM_IFS],
    db_ctrl_intf.controller   to_peripheral
);
    // Parameters
    localparam int KEY_WID   = to_peripheral.KEY_WID;
    localparam int VALUE_WID = to_peripheral.VALUE_WID;

    localparam int NUM_IFS__POW2 = 2**SEL_WID;

    db_ctrl_intf_parameter_check param_check_0 (.from_controller(from_controller[0]), .to_peripheral);

    generate
        if (NUM_IFS > 1) begin : g__mux
            // (Local) Imports
            import db_pkg::*;

            // (Local) Interfaces
            db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) __to_peripheral (.clk);

            // (Local) signals
            logic [SEL_WID-1:0]     __mux_sel;
            logic                   from_controller_rdy       [NUM_IFS];
            logic                   from_controller_ack       [NUM_IFS];
            logic                   from_controller_req       [NUM_IFS__POW2];
            command_t               from_controller_command   [NUM_IFS__POW2];
            logic [KEY_WID-1:0]     from_controller_key       [NUM_IFS__POW2];
            logic [VALUE_WID-1:0]   from_controller_set_value [NUM_IFS__POW2];
            status_t                from_controller_status    [NUM_IFS];
            logic                   from_controller_get_valid [NUM_IFS];
            logic [VALUE_WID-1:0]   from_controller_get_value [NUM_IFS];
            logic [KEY_WID-1:0]     from_controller_get_key   [NUM_IFS];

            // Convert between array of signals and array of interfaces
            for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                assign from_controller[g_if].rdy       = from_controller_rdy[g_if];
                assign from_controller[g_if].ack       = from_controller_ack[g_if];
                assign from_controller_req      [g_if] = from_controller[g_if].req;
                assign from_controller_command  [g_if] = from_controller[g_if].command;
                assign from_controller_key      [g_if] = from_controller[g_if].key;
                assign from_controller_set_value[g_if] = from_controller[g_if].set_value;
                assign from_controller[g_if].status    = from_controller_status[g_if];
                assign from_controller[g_if].get_valid = from_controller_get_valid[g_if];
                assign from_controller[g_if].get_value = from_controller_get_value[g_if];
                assign from_controller[g_if].get_key   = from_controller_get_key[g_if];
            end : g__if
            // Assign 'out-of-range' values
            for (genvar g_if = NUM_IFS; g_if < NUM_IFS__POW2; g_if++) begin : g__if_out_of_range
                assign from_controller_req      [g_if] = 1'b0;
                assign from_controller_command  [g_if] = COMMAND_NOP;
                assign from_controller_key      [g_if] = '0;
                assign from_controller_set_value[g_if] = '0;
            end : g__if_out_of_range

            initial __mux_sel = '0;
            always @(posedge clk) if (__to_peripheral.req && __to_peripheral.rdy) __mux_sel <= mux_sel;

            // Proxy requests
            db_ctrl_intf_proxy i_db_ctrl_intf_proxy (
                .clk  ( clk ),
                .srst ( srst ),
                .from_controller ( __to_peripheral ),
                .to_peripheral   ( to_peripheral )
            );

            // Mux requests
            always_comb begin
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == mux_sel) from_controller_rdy[i] = __to_peripheral.rdy;
                    else              from_controller_rdy[i] = 1'b0;
                end
            end
            assign __to_peripheral.req       = from_controller_req       [mux_sel];
            assign __to_peripheral.command   = from_controller_command   [mux_sel];
            assign __to_peripheral.key       = from_controller_key       [mux_sel];
            assign __to_peripheral.set_value = from_controller_set_value [mux_sel];

            // Demux result
            initial from_controller_ack = '{NUM_IFS{1'b0}};
            always @(posedge clk) begin
                if (srst) from_controller_ack <= '{NUM_IFS{1'b0}};
                else begin
                    for (int i = 0; i < NUM_IFS; i++) begin
                        if (i == __mux_sel) from_controller_ack[i] <= __to_peripheral.ack;
                        else                from_controller_ack[i] <= 1'b0;
                    end
                end
            end

            always_ff @(posedge clk) begin
                for (int i = 0; i < NUM_IFS; i++) begin
                    from_controller_status   [i] <= __to_peripheral.status;
                    from_controller_get_valid[i] <= __to_peripheral.get_valid;
                    from_controller_get_key  [i] <= __to_peripheral.get_key;
                    from_controller_get_value[i] <= __to_peripheral.get_value;
                end
            end
        end : g__mux
        else begin : g__connector
            // Single interface, no mux required
            db_ctrl_intf_connector i_db_ctrl_intf_connector (
                .from_controller ( from_controller[0] ),
                .to_peripheral   ( to_peripheral )
            );
        end : g__connector
    endgenerate
endmodule


// Database control interface static 2:1 mux component
// (built using db_ctrl_intf_mux as a basis but provides
//  simplified interface for most common mux configuration)
module db_ctrl_intf_2to1_mux (
    input logic             clk,
    input logic             srst,
    input logic             mux_sel,
    db_ctrl_intf.peripheral from_controller_0,
    db_ctrl_intf.peripheral from_controller_1,
    db_ctrl_intf.controller to_peripheral
);
    // Parameters
    localparam int KEY_WID   = to_peripheral.KEY_WID;
    localparam int VALUE_WID = to_peripheral.VALUE_WID;

    localparam int SEL_WID = 1;
    logic [SEL_WID-1:0] __mux_sel;

    // Interfaces
    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) from_controller [2] (.clk);

    db_ctrl_intf_connector i_db_ctrl_intf_connector_0 (
        .from_controller ( from_controller_0 ),
        .to_peripheral   ( from_controller[0] )
    );

    db_ctrl_intf_connector i_db_ctrl_intf_connector_1 (
        .from_controller ( from_controller_1 ),
        .to_peripheral   ( from_controller[1] )
    );

    // Mux
    db_ctrl_intf_mux #(
        .NUM_IFS ( 2 )
    ) i_db_ctrl_intf_mux_0 (.*);

endmodule


// Database control interface mux component
// - muxes between two control interfaces, with strict
//   priority granted to the 0th interface
module db_ctrl_intf_prio_mux (
    input logic clk,
    input logic srst,
    db_ctrl_intf.peripheral from_controller_hi_prio,
    db_ctrl_intf.peripheral from_controller_lo_prio,
    db_ctrl_intf.controller to_peripheral
);
    // Parameters
    localparam int KEY_WID   = to_peripheral.KEY_WID;
    localparam int VALUE_WID = to_peripheral.VALUE_WID;

    // Interfaces
    db_ctrl_intf #(.KEY_WID(KEY_WID), .VALUE_WID(VALUE_WID)) from_controller [2] (.clk);

    // Signals
    logic mux_sel;

    // Proxy requests
    db_ctrl_intf_proxy i_db_ctrl_intf_proxy__hi_prio (
        .clk  ( clk ),
        .srst ( srst ),
        .from_controller ( from_controller_hi_prio ),
        .to_peripheral   ( from_controller[1] )
    );

    db_ctrl_intf_proxy i_db_ctrl_intf_proxy__lo_prio (
        .clk  ( clk ),
        .srst ( srst ),
        .from_controller ( from_controller_lo_prio ),
        .to_peripheral   ( from_controller[0] )
    );

    assign mux_sel = from_controller[1].req ? 1 : 0;

    // Mux
    db_ctrl_intf_mux #(
        .NUM_IFS ( 2 )
    ) i_db_ctrl_intf_mux (.*);

endmodule : db_ctrl_intf_prio_mux


// Database control interface static demux component
// - provides static (hard) demux to NUM_IFS control interfaces
module db_ctrl_intf_demux #(
    parameter int  NUM_IFS = 2,
    // Derived parameters (don't override)
    parameter int  SEL_WID = NUM_IFS > 1 ? $clog2(NUM_IFS) : 1
) (
    input logic               clk,
    input logic               srst,
    input logic [SEL_WID-1:0] demux_sel,
    db_ctrl_intf.peripheral   from_controller,
    db_ctrl_intf.controller   to_peripheral [NUM_IFS]
);
    // Parameters
    localparam int KEY_WID = from_controller.KEY_WID;
    localparam int VALUE_WID = from_controller.VALUE_WID;

    db_ctrl_intf_parameter_check param_check_0 (.from_controller, .to_peripheral(to_peripheral[0]));

    generate
        if (NUM_IFS > 1) begin : g__demux
            // (Local) Imports
            import db_pkg::*;

            typedef struct packed {
                logic [KEY_WID-1:0]   key;
                command_t             command;
                logic [VALUE_WID-1:0] value;
            } req_ctxt_t;

            // (Local) signals
            logic [SEL_WID-1:0]    __demux_sel;
            logic                  to_peripheral_rdy       [NUM_IFS];
            logic                  to_peripheral_ack       [NUM_IFS];
            status_t               to_peripheral_status    [NUM_IFS];
            logic                  to_peripheral_get_valid [NUM_IFS];
            logic [KEY_WID-1:0]    to_peripheral_get_key   [NUM_IFS];
            logic [VALUE_WID-1:0]  to_peripheral_get_value [NUM_IFS];
            logic                  to_peripheral_req       [NUM_IFS];

            logic      req;
            logic      rdy;
            logic      ack;
            logic      req_pending;
            req_ctxt_t req_ctxt;

            // Convert between array of signals and array of interfaces
            for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                assign to_peripheral_rdy      [g_if] = to_peripheral[g_if].rdy;
                assign to_peripheral_ack      [g_if] = to_peripheral[g_if].ack;
                assign to_peripheral_status   [g_if] = to_peripheral[g_if].status;
                assign to_peripheral_get_valid[g_if] = to_peripheral[g_if].get_valid;
                assign to_peripheral_get_key  [g_if] = to_peripheral[g_if].get_key;
                assign to_peripheral_get_value[g_if] = to_peripheral[g_if].get_value;
                assign to_peripheral[g_if].req       = to_peripheral_req[g_if];
                assign to_peripheral[g_if].command   = req_ctxt.command;
                assign to_peripheral[g_if].key       = req_ctxt.key;
                assign to_peripheral[g_if].set_value = req_ctxt.value;
            end : g__if

            // Latch request
            initial req = 1'b0;
            always @(posedge clk) begin
                if (srst)                                            req <= 1'b0;
                else if (from_controller.req && from_controller.rdy) req <= 1'b1;
                else if (rdy)                                        req <= 1'b0;
            end

            always_ff @(posedge clk) if (from_controller.req && from_controller.rdy) begin
                req_ctxt.key <= from_controller.key;
                req_ctxt.command <= from_controller.command;
                req_ctxt.value <= from_controller.set_value;
            end

            // Latch mux select
            initial __demux_sel = '0;
            always @(posedge clk) begin
                if (srst) __demux_sel <= '0;
                else if (from_controller.req && from_controller.rdy) __demux_sel <= demux_sel;
            end

            // Maintain context for open transactions
            initial req_pending = 1'b0;
            always @(posedge clk) begin
                if (srst)                                            req_pending <= 1'b0;
                else if (from_controller.ack)                        req_pending <= 1'b0;
                else if (from_controller.req && from_controller.rdy) req_pending <= 1'b1;
            end

            // Ready to accept new transaction if none are currently pending
            initial from_controller.rdy = 1'b0;
            always @(posedge clk) begin
                if (srst)                         from_controller.rdy <= 1'b0;
                else begin
                    if (from_controller.req)      from_controller.rdy <= 1'b0;
                    else if (from_controller.ack) from_controller.rdy <= 1'b1;
                    else if (req_pending)         from_controller.rdy <= 1'b0;
                    else                          from_controller.rdy <= 1'b1;
                end
            end

            // Demux control signals
            always_comb begin
                rdy = to_peripheral_rdy [__demux_sel];
                ack = to_peripheral_ack [__demux_sel];
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == __demux_sel) to_peripheral_req[i] = req;
                    else                  to_peripheral_req[i] = 1'b0;
                end
            end

            // Latch result
            initial from_controller.ack = 1'b0;
            always @(posedge clk) begin
                if (srst) from_controller.ack <= 1'b0;
                else      from_controller.ack <= ack;
            end

            always_ff @(posedge clk) begin
                from_controller.status    <= to_peripheral_status   [__demux_sel];
                from_controller.get_valid <= to_peripheral_get_valid[__demux_sel];
                from_controller.get_key   <= to_peripheral_get_key  [__demux_sel];
                from_controller.get_value <= to_peripheral_get_value[__demux_sel];
            end

        end : g__demux
        else begin : g__connector
            // Single interface, no demux required
            db_ctrl_intf_connector i_db_ctrl_intf_connector (
                .from_controller ( from_controller ),
                .to_peripheral   ( to_peripheral[0] )
            );
        end : g__connector
    endgenerate
endmodule

