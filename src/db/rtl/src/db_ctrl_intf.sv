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

interface db_ctrl_intf #(
    parameter type KEY_T   = logic[7:0],
    parameter type VALUE_T = logic [7:0]
) (
    input logic clk
);

    // Imports
    import db_pkg::*;

    // Signals
    // -- Controller to peripheral
    logic        req;
    command_t    command;
    KEY_T        key;
    VALUE_T      set_value;

    // -- Peripheral to controller
    logic        rdy;
    logic        ack;
    status_t     status;
    logic        get_valid;
    KEY_T        get_key;
    VALUE_T      get_value;

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
        default input #1step output #1step;
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
        fork
            begin
                fork
                    begin
                        wait (cb.rdy);
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
            input KEY_T _key
        );
        cb.key <= _key;
    endtask

    // Drive value (for request)
    task _set_value(
            input VALUE_T _value
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
            output KEY_T _key
        );
        _key = cb.get_key;
    endtask

    // Receive value (for response)
    task _get_value(
            output VALUE_T _value
        );
        _value = cb.get_value;
    endtask

endinterface : db_ctrl_intf


// Database control interface controller termination helper module
module db_ctrl_intf_controller_term (
    db_ctrl_intf.controller ctrl_if
);
    // Tie off controller outputs
    assign ctrl_if.req = 1'b0;
    assign ctrl_if.command = db_pkg::COMMAND_NOP;

endmodule : db_ctrl_intf_controller_term


// Database control interface peripheral termination helper module
module db_ctrl_intf_peripheral_term (
    db_ctrl_intf.peripheral ctrl_if
);
    // Tie off peripheral outputs
    assign ctrl_if.rdy = 1'b0;
    assign ctrl_if.ack = 1'b0;
    assign ctrl_if.status = db_pkg::STATUS_UNSPECIFIED;

endmodule : db_ctrl_intf_peripheral_term


// Database control interface (back-to-back) connector helper module
module db_ctrl_intf_connector (
    db_ctrl_intf.peripheral ctrl_if_from_controller,
    db_ctrl_intf.controller ctrl_if_to_peripheral
);
    // Connect signals (controller -> peripheral)
    assign ctrl_if_to_peripheral.req = ctrl_if_from_controller.req;
    assign ctrl_if_to_peripheral.command = ctrl_if_from_controller.command;
    assign ctrl_if_to_peripheral.key = ctrl_if_from_controller.key;
    assign ctrl_if_to_peripheral.set_value = ctrl_if_from_controller.set_value;

    // Connect signals (peripheral -> controller)
    assign ctrl_if_from_controller.rdy = ctrl_if_to_peripheral.rdy;
    assign ctrl_if_from_controller.ack = ctrl_if_to_peripheral.ack;
    assign ctrl_if_from_controller.status = ctrl_if_to_peripheral.status;
    assign ctrl_if_from_controller.get_valid = ctrl_if_to_peripheral.get_valid;
    assign ctrl_if_from_controller.get_key = ctrl_if_to_peripheral.get_key;
    assign ctrl_if_from_controller.get_value = ctrl_if_to_peripheral.get_value;

endmodule : db_ctrl_intf_connector


// Database control interface proxy stage
module db_ctrl_intf_proxy (
    input logic clk,
    input logic srst,
    db_ctrl_intf.peripheral ctrl_if_from_controller,
    db_ctrl_intf.controller ctrl_if_to_peripheral
);
    // Signals
    logic pending;
    logic in_progress;

    // Proxy requests
    initial pending = 1'b0;
    always @(posedge clk) begin
        if (srst)                                                            pending <= 1'b0;
        else if (ctrl_if_from_controller.req && ctrl_if_from_controller.rdy) pending <= 1'b1;
        else if (ctrl_if_to_peripheral.rdy)                                  pending <= 1'b0;
    end

    initial in_progress = 1'b0;
    always @(posedge clk) begin
        if (srst)                                      in_progress <= 1'b0;
        else if (pending && ctrl_if_to_peripheral.rdy) in_progress <= 1'b1;
        else if (ctrl_if_to_peripheral.ack)            in_progress <= 1'b0;
    end

    assign ctrl_if_to_peripheral.req = pending;
    assign ctrl_if_from_controller.rdy = !pending && !in_progress;

    // Latch request context
    always_ff @(posedge clk) begin
        if (ctrl_if_from_controller.req && ctrl_if_from_controller.rdy) begin
            ctrl_if_to_peripheral.command   <= ctrl_if_from_controller.command;
            ctrl_if_to_peripheral.key       <= ctrl_if_from_controller.key;
            ctrl_if_to_peripheral.set_value <= ctrl_if_from_controller.set_value;
        end
    end

    // Pass response directly
    assign ctrl_if_from_controller.ack       = ctrl_if_to_peripheral.ack;
    assign ctrl_if_from_controller.status    = ctrl_if_to_peripheral.status;
    assign ctrl_if_from_controller.get_valid = ctrl_if_to_peripheral.get_valid;
    assign ctrl_if_from_controller.get_key   = ctrl_if_to_peripheral.get_key;
    assign ctrl_if_from_controller.get_value = ctrl_if_to_peripheral.get_value;

endmodule : db_ctrl_intf_proxy

// Database control interface static mux component
// - provides static (hard) mux between NUM_IFS control interfaces
module db_ctrl_intf_mux #(
    parameter int  NUM_IFS = 2,
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0]
) (
    input logic             clk,
    input logic             srst,
    input int               mux_sel,
    db_ctrl_intf.peripheral ctrl_if_from_controller [NUM_IFS],
    db_ctrl_intf.controller ctrl_if_to_peripheral
);

    generate
        if (NUM_IFS > 1) begin : g__mux
            // (Local) Imports
            import db_pkg::*;

            // (Local) Parameters
            localparam int MUX_SEL_WID = $clog2(NUM_IFS);

            // (Local) Typedefs
            typedef logic [MUX_SEL_WID-1:0] mux_sel_t;

            // (Local) Interfaces
            db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) __ctrl_if_to_peripheral (.clk(clk));

            // (Local) signals
            mux_sel_t __mux_sel;
            mux_sel_t __mux_sel_reg;
            logic     ctrl_if_from_controller_rdy       [NUM_IFS];
            logic     ctrl_if_from_controller_ack       [NUM_IFS];
            logic     ctrl_if_from_controller_req       [NUM_IFS];
            command_t ctrl_if_from_controller_command   [NUM_IFS];
            KEY_T     ctrl_if_from_controller_key       [NUM_IFS];
            VALUE_T   ctrl_if_from_controller_set_value [NUM_IFS];
            status_t  ctrl_if_from_controller_status    [NUM_IFS];
            logic     ctrl_if_from_controller_get_valid [NUM_IFS];
            VALUE_T   ctrl_if_from_controller_get_value [NUM_IFS];
            KEY_T     ctrl_if_from_controller_get_key   [NUM_IFS];

            // Convert between array of signals and array of interfaces
            for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                assign ctrl_if_from_controller[g_if].rdy       = ctrl_if_from_controller_rdy[g_if];
                assign ctrl_if_from_controller[g_if].ack       = ctrl_if_from_controller_ack[g_if];
                assign ctrl_if_from_controller_req      [g_if] = ctrl_if_from_controller[g_if].req;
                assign ctrl_if_from_controller_command  [g_if] = ctrl_if_from_controller[g_if].command;
                assign ctrl_if_from_controller_key      [g_if] = ctrl_if_from_controller[g_if].key;
                assign ctrl_if_from_controller_set_value[g_if] = ctrl_if_from_controller[g_if].set_value;
                assign ctrl_if_from_controller[g_if].status    = ctrl_if_from_controller_status[g_if];
                assign ctrl_if_from_controller[g_if].get_valid = ctrl_if_from_controller_get_valid[g_if];
                assign ctrl_if_from_controller[g_if].get_value = ctrl_if_from_controller_get_value[g_if];
                assign ctrl_if_from_controller[g_if].get_key   = ctrl_if_from_controller_get_key[g_if];
            end : g__if

            assign __mux_sel = mux_sel[MUX_SEL_WID-1:0] % NUM_IFS;

            initial __mux_sel_reg = '0;
            always @(posedge clk) if (__ctrl_if_to_peripheral.req && __ctrl_if_to_peripheral.rdy) __mux_sel_reg <= __mux_sel;

            // Proxy requests
            db_ctrl_intf_proxy i_db_ctrl_intf_proxy (
                .clk  ( clk ),
                .srst ( srst ),
                .ctrl_if_from_controller ( __ctrl_if_to_peripheral ),
                .ctrl_if_to_peripheral   ( ctrl_if_to_peripheral )
            );

            // Mux requests
            always_comb begin
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == __mux_sel) ctrl_if_from_controller_rdy[i] = __ctrl_if_to_peripheral.rdy;
                    else                ctrl_if_from_controller_rdy[i] = 1'b0;
                end
            end
            assign __ctrl_if_to_peripheral.req       = ctrl_if_from_controller_req       [__mux_sel];
            assign __ctrl_if_to_peripheral.command   = ctrl_if_from_controller_command   [__mux_sel];
            assign __ctrl_if_to_peripheral.key       = ctrl_if_from_controller_key       [__mux_sel];
            assign __ctrl_if_to_peripheral.set_value = ctrl_if_from_controller_set_value [__mux_sel];

            // Demux result
            initial ctrl_if_from_controller_ack = '{NUM_IFS{1'b0}};
            always @(posedge clk) begin
                if (srst) ctrl_if_from_controller_ack <= '{NUM_IFS{1'b0}};
                else begin
                    for (int i = 0; i < NUM_IFS; i++) begin
                        if (i == __mux_sel_reg) ctrl_if_from_controller_ack[i] <= __ctrl_if_to_peripheral.ack;
                        else                    ctrl_if_from_controller_ack[i] <= 1'b0;
                    end
                end
            end

            always_ff @(posedge clk) begin
                for (int i = 0; i < NUM_IFS; i++) begin
                    ctrl_if_from_controller_status   [i] <= __ctrl_if_to_peripheral.status;
                    ctrl_if_from_controller_get_valid[i] <= __ctrl_if_to_peripheral.get_valid;
                    ctrl_if_from_controller_get_key  [i] <= __ctrl_if_to_peripheral.get_key;
                    ctrl_if_from_controller_get_value[i] <= __ctrl_if_to_peripheral.get_value;
                end
            end
        end : g__mux
        else begin : g__connector
            // Single interface, no mux required
            db_ctrl_intf_connector i_db_ctrl_intf_connector (
                .ctrl_if_from_controller ( ctrl_if_from_controller[0] ),
                .ctrl_if_to_peripheral   ( ctrl_if_to_peripheral )
            );
        end : g__connector
    endgenerate
endmodule


// Database control interface static 2:1 mux component
// (built using db_intf_mux as a basis but provides
//  simplified interface for most common mux configuration)
module db_ctrl_intf_2to1_mux #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0]
) (
    input logic             clk,
    input logic             srst,
    input logic             mux_sel,
    db_ctrl_intf.peripheral ctrl_if_from_controller_0,
    db_ctrl_intf.peripheral ctrl_if_from_controller_1,
    db_ctrl_intf.controller ctrl_if_to_peripheral
);
    // Interfaces
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) ctrl_if_from_controller [2] (.clk(clk));

    db_ctrl_intf_connector i_db_ctrl_intf_connector_0 (
        .ctrl_if_from_controller ( ctrl_if_from_controller_0 ),
        .ctrl_if_to_peripheral   ( ctrl_if_from_controller[0] )
    );

    db_ctrl_intf_connector i_db_ctrl_intf_connector_1 (
        .ctrl_if_from_controller ( ctrl_if_from_controller_1 ),
        .ctrl_if_to_peripheral   ( ctrl_if_from_controller[1] )
    );

    // Mux
    db_ctrl_intf_mux #(
        .NUM_IFS ( 2 ),
        .KEY_T   ( KEY_T ),
        .VALUE_T ( VALUE_T )
    ) i_db_ctrl_intf_mux (
        .clk ( clk ),
        .srst ( srst ),
        .mux_sel ( {31'b0, mux_sel} ),
        .ctrl_if_from_controller ( ctrl_if_from_controller ),
        .ctrl_if_to_peripheral   ( ctrl_if_to_peripheral )
    );
endmodule


// Database control interface mux component
// - muxes between two control interfaces, with strict
//   priority granted to the 0th interface
module db_ctrl_intf_prio_mux #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0]
) (
    input logic clk,
    input logic srst,
    db_ctrl_intf.peripheral ctrl_if_from_controller_hi_prio,
    db_ctrl_intf.peripheral ctrl_if_from_controller_lo_prio,
    db_ctrl_intf.controller ctrl_if_to_peripheral
);
    // Interfaces
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) __ctrl_if_from_controller_hi_prio (.clk(clk));
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(VALUE_T)) __ctrl_if_from_controller_lo_prio (.clk(clk));

    // Proxy requests
    db_ctrl_intf_proxy i_db_ctrl_intf_proxy__hi_prio (
        .clk  ( clk ),
        .srst ( srst ),
        .ctrl_if_from_controller ( ctrl_if_from_controller_hi_prio ),
        .ctrl_if_to_peripheral   ( __ctrl_if_from_controller_hi_prio )
    );

    db_ctrl_intf_proxy i_db_ctrl_intf_proxy__lo_prio (
        .clk  ( clk ),
        .srst ( srst ),
        .ctrl_if_from_controller ( ctrl_if_from_controller_lo_prio ),
        .ctrl_if_to_peripheral   ( __ctrl_if_from_controller_lo_prio )
    );

    // (Static) output mux (strict priority to hi_prio input)
    db_ctrl_intf_2to1_mux #(
        .KEY_T   ( KEY_T ),
        .VALUE_T ( VALUE_T )
    ) i_db_ctrl_intf_2to1_mux (
        .clk                       ( clk ),
        .srst                      ( srst ),
        .mux_sel                   ( __ctrl_if_from_controller_hi_prio.req ),
        .ctrl_if_from_controller_0 ( __ctrl_if_from_controller_lo_prio ),
        .ctrl_if_from_controller_1 ( __ctrl_if_from_controller_hi_prio ),
        .ctrl_if_to_peripheral     ( ctrl_if_to_peripheral )
    );

endmodule : db_ctrl_intf_prio_mux


// Database control interface static demux component
// - provides static (hard) demux to NUM_IFS control interfaces
module db_ctrl_intf_demux #(
    parameter int  NUM_IFS = 2,
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[7:0]
) (
    input logic             clk,
    input logic             srst,
    input int unsigned      demux_sel,
    db_ctrl_intf.peripheral ctrl_if_from_controller,
    db_ctrl_intf.controller ctrl_if_to_peripheral [NUM_IFS]
);
    generate
        if (NUM_IFS > 1) begin : g__demux
            // (Local) Imports
            import db_pkg::*;

            // (Local) Parameters
            localparam int MUX_SEL_WID = $clog2(NUM_IFS);

            // (Local) Typedefs
            typedef logic [MUX_SEL_WID-1:0] mux_sel_t;

            typedef struct packed {
                mux_sel_t mux_sel;
                KEY_T     key;
                command_t command;
                VALUE_T   value;
            } req_ctxt_t;

            // (Local) signals
            mux_sel_t  __demux_sel;
            logic      ctrl_if_to_peripheral_rdy       [NUM_IFS];
            logic      ctrl_if_to_peripheral_ack       [NUM_IFS];
            status_t   ctrl_if_to_peripheral_status    [NUM_IFS];
            logic      ctrl_if_to_peripheral_get_valid [NUM_IFS];
            KEY_T      ctrl_if_to_peripheral_get_key   [NUM_IFS];
            VALUE_T    ctrl_if_to_peripheral_get_value [NUM_IFS];
            logic      ctrl_if_to_peripheral_req       [NUM_IFS];

            logic      req;
            logic      rdy;
            logic      ack;
            logic      req_pending;
            req_ctxt_t req_ctxt;

            // Convert between array of signals and array of interfaces
            for (genvar g_if = 0; g_if < NUM_IFS; g_if++) begin : g__if
                assign ctrl_if_to_peripheral_rdy      [g_if] = ctrl_if_to_peripheral[g_if].rdy;
                assign ctrl_if_to_peripheral_ack      [g_if] = ctrl_if_to_peripheral[g_if].ack;
                assign ctrl_if_to_peripheral_status   [g_if] = ctrl_if_to_peripheral[g_if].status;
                assign ctrl_if_to_peripheral_get_valid[g_if] = ctrl_if_to_peripheral[g_if].get_valid;
                assign ctrl_if_to_peripheral_get_key  [g_if] = ctrl_if_to_peripheral[g_if].get_key;
                assign ctrl_if_to_peripheral_get_value[g_if] = ctrl_if_to_peripheral[g_if].get_value;
                assign ctrl_if_to_peripheral[g_if].req       = ctrl_if_to_peripheral_req[g_if];
                assign ctrl_if_to_peripheral[g_if].command   = req_ctxt.command;
                assign ctrl_if_to_peripheral[g_if].key       = req_ctxt.key;
                assign ctrl_if_to_peripheral[g_if].set_value = req_ctxt.value;
            end : g__if

            // Latch request
            initial req = 1'b0;
            always @(posedge clk) begin
                if (srst)                                                            req <= 1'b0;
                else if (ctrl_if_from_controller.req && ctrl_if_from_controller.rdy) req <= 1'b1;
                else if (rdy)                                                        req <= 1'b0;
            end

            always_ff @(posedge clk) if (ctrl_if_from_controller.req && ctrl_if_from_controller.rdy) begin
                req_ctxt.key <= ctrl_if_from_controller.key;
                req_ctxt.command <= ctrl_if_from_controller.command;
                req_ctxt.value <= ctrl_if_from_controller.set_value;
            end

            // Latch mux select
            initial __demux_sel = '0;
            always @(posedge clk) begin
                if (srst) __demux_sel <= '0;
                else if (ctrl_if_from_controller.req && ctrl_if_from_controller.rdy) __demux_sel <= demux_sel[MUX_SEL_WID-1:0] % NUM_IFS;
            end

            // Maintain context for open transactions
            initial req_pending = 1'b0;
            always @(posedge clk) begin
                if (srst)                                                            req_pending <= 1'b0;
                else if (ctrl_if_from_controller.ack)                                req_pending <= 1'b0;
                else if (ctrl_if_from_controller.req && ctrl_if_from_controller.rdy) req_pending <= 1'b1;
            end

            // Ready to accept new transaction if none are currently pending
            initial ctrl_if_from_controller.rdy = 1'b0;
            always @(posedge clk) begin
                if (srst)                                 ctrl_if_from_controller.rdy <= 1'b0;
                else begin
                    if (ctrl_if_from_controller.req)      ctrl_if_from_controller.rdy <= 1'b0;
                    else if (ctrl_if_from_controller.ack) ctrl_if_from_controller.rdy <= 1'b1;
                    else if (req_pending)                 ctrl_if_from_controller.rdy <= 1'b0;
                    else                                  ctrl_if_from_controller.rdy <= 1'b1;
                end
            end

            // Demux control signals
            always_comb begin
                rdy = ctrl_if_to_peripheral_rdy [__demux_sel];
                ack = ctrl_if_to_peripheral_ack [__demux_sel];
                for (int i = 0; i < NUM_IFS; i++) begin
                    if (i == __demux_sel) ctrl_if_to_peripheral_req[i] = req;
                    else                  ctrl_if_to_peripheral_req[i] = 1'b0;
                end
            end

            // Latch result
            initial ctrl_if_from_controller.ack = 1'b0;
            always @(posedge clk) begin
                if (srst) ctrl_if_from_controller.ack <= 1'b0;
                else      ctrl_if_from_controller.ack <= ack;
            end

            always_ff @(posedge clk) begin
                ctrl_if_from_controller.status    <= ctrl_if_to_peripheral_status   [__demux_sel];
                ctrl_if_from_controller.get_valid <= ctrl_if_to_peripheral_get_valid[__demux_sel];
                ctrl_if_from_controller.get_key   <= ctrl_if_to_peripheral_get_key  [__demux_sel];
                ctrl_if_from_controller.get_value <= ctrl_if_to_peripheral_get_value[__demux_sel];
            end

        end : g__demux
        else begin : g__connector
            // Single interface, no demux required
            db_ctrl_intf_connector i_db_ctrl_intf_connector (
                .ctrl_if_from_controller ( ctrl_if_from_controller ),
                .ctrl_if_to_peripheral   ( ctrl_if_to_peripheral[0] )
            );
        end : g__connector
    endgenerate
endmodule

