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
    parameter type VALUE_T = logic [31:0]
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


// Database control interface static mux component
// - provides static (hard) mux between two control interfaces
module db_ctrl_intf_mux (
    input logic             mux_sel,
    db_ctrl_intf.peripheral ctrl_if_from_controller_0,
    db_ctrl_intf.peripheral ctrl_if_from_controller_1,
    db_ctrl_intf.controller ctrl_if_to_peripheral
);

    // Mux requests
    assign ctrl_if_to_peripheral.req       = mux_sel ? ctrl_if_from_controller_1.req       : ctrl_if_from_controller_0.req;
    assign ctrl_if_to_peripheral.command   = mux_sel ? ctrl_if_from_controller_1.command   : ctrl_if_from_controller_0.command;
    assign ctrl_if_to_peripheral.key       = mux_sel ? ctrl_if_from_controller_1.key       : ctrl_if_from_controller_0.key;
    assign ctrl_if_to_peripheral.set_value = mux_sel ? ctrl_if_from_controller_1.set_value : ctrl_if_from_controller_0.set_value;

    // Demux responses
    assign ctrl_if_from_controller_0.rdy       = mux_sel ? 1'b0 : ctrl_if_to_peripheral.rdy;
    assign ctrl_if_from_controller_0.ack       = mux_sel ? 1'b0 : ctrl_if_to_peripheral.ack;
    assign ctrl_if_from_controller_0.status    = ctrl_if_to_peripheral.status;
    assign ctrl_if_from_controller_0.get_valid = ctrl_if_to_peripheral.get_valid;
    assign ctrl_if_from_controller_0.get_key   = ctrl_if_to_peripheral.get_key;
    assign ctrl_if_from_controller_0.get_value = ctrl_if_to_peripheral.get_value;

    assign ctrl_if_from_controller_1.rdy       = mux_sel ? ctrl_if_to_peripheral.rdy : 1'b0;
    assign ctrl_if_from_controller_1.ack       = mux_sel ? ctrl_if_to_peripheral.ack : 1'b0;
    assign ctrl_if_from_controller_1.status    = ctrl_if_to_peripheral.status;
    assign ctrl_if_from_controller_1.get_valid = ctrl_if_to_peripheral.get_valid;
    assign ctrl_if_from_controller_1.get_key   = ctrl_if_to_peripheral.get_key;
    assign ctrl_if_from_controller_1.get_value = ctrl_if_to_peripheral.get_value;

endmodule : db_ctrl_intf_mux

// Database control interface mux component
// - muxes between two control interfaces, with strict
//   priority granted to the 0th interface
module db_ctrl_intf_prio_mux (
    input logic clk,
    input logic srst,
    db_ctrl_intf.peripheral ctrl_if_from_controller_hi_prio,
    db_ctrl_intf.peripheral ctrl_if_from_controller_lo_prio,
    db_ctrl_intf.controller ctrl_if_to_peripheral
);

    // Signals
    logic       req [2];
    logic       mux_sel;
    logic       mux_sel_reg;
    logic       req_pending;

    // Request vector
    assign req[0] = ctrl_if_from_controller_hi_prio.req;
    assign req[1] = ctrl_if_from_controller_lo_prio.req;

    // Maintain context for open transactions
    initial req_pending = 1'b0;
    always @(posedge clk) begin
        if (srst)                           req_pending <= 1'b0;
        else if (ctrl_if_to_peripheral.ack) req_pending <= 1'b0;
        else if (req[mux_sel])              req_pending <= 1'b1;
    end

    // Mux select
    always_comb begin
        mux_sel = mux_sel_reg;
        if (!req_pending) mux_sel = req[0]? 0 : 1;
    end

    initial mux_sel_reg = 0;
    always @(posedge clk) begin
        if (srst) mux_sel_reg <= 0;
        else      mux_sel_reg <= mux_sel;
    end

    // (Static) output mux
    db_ctrl_intf_mux i_db_ctrl_intf_mux (
        .mux_sel                   ( mux_sel ),
        .ctrl_if_from_controller_0 ( ctrl_if_from_controller_hi_prio ),
        .ctrl_if_from_controller_1 ( ctrl_if_from_controller_lo_prio ),
        .ctrl_if_to_peripheral     ( ctrl_if_to_peripheral )
    );

endmodule : db_ctrl_intf_prio_mux
