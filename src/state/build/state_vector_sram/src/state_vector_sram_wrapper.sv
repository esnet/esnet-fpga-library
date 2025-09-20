module state_vector_sram_wrapper
    import state_pkg::*;
#(
    parameter int ID_WID = 15,
    parameter vector_t SPEC = '{
        NUM_ELEMENTS : 8,
        ELEMENTS: '{
            0       : '{ELEMENT_TYPE_READ,          1, 1, RETURN_MODE_PREV_STATE, REAP_MODE_PERSIST},
            default : '{ELEMENT_TYPE_COUNTER_COND, 64, 1, RETURN_MODE_PREV_STATE, REAP_MODE_CLEAR}
        }
    },
    parameter int STATE_WID = getStateVectorSize(SPEC),
    parameter int UPDATE_WID = getUpdateVectorSize(SPEC)
) (
    // Clock/reset
    input  logic                  clk,
    input  logic                  srst,

    input  logic                  en,
    output logic                  init_done,

    // Control interface
    input  logic                  db_ctrl_req,
    input  db_pkg::command_t      db_ctrl_command,
    input  logic [ID_WID-1:0]     db_ctrl_key,
    input  logic [STATE_WID-1:0]  db_ctrl_set_value,
    output logic                  db_ctrl_rdy,
    output logic                  db_ctrl_ack,
    output db_pkg::status_t       db_ctrl_status,
    output logic                  db_ctrl_get_valid,
    output logic [ID_WID-1:0]     db_ctrl_get_key,
    output logic [STATE_WID-1:0]  db_ctrl_get_value,

    // Info interface
    output db_pkg::type_t         info_type,
    output db_pkg::subtype_t      info_subtype,
    output logic [31:0]           info_size,

    // Update interface (datapath)
    input  logic                  update_req,
    input  update_ctxt_t          update_ctxt,
    input  logic [ID_WID-1:0]     update_id,
    input  logic                  update_init,
    input  logic [UPDATE_WID-1:0] update_update,
    output logic                  update_rdy,
    output logic                  update_ack,
    output logic                  update_state,

    // Update interface (control)
    input  logic                  ctrl_req,
    input  update_ctxt_t          ctrl_ctxt,
    input  logic [ID_WID-1:0]     ctrl_id,
    input  logic                  ctrl_init,
    input  logic [UPDATE_WID-1:0] ctrl_update,
    output logic                  ctrl_rdy,
    output logic                  ctrl_ack,
    output logic                  ctrl_state

);

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic db_init;
    logic db_init_done;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_ctrl_intf #(.KEY_WID(ID_WID), .VALUE_WID(STATE_WID)) db_ctrl_if (.clk);
    db_info_intf info_if ();
    state_intf #(.ID_WID(ID_WID), .STATE_WID(STATE_WID), .UPDATE_WID(UPDATE_WID)) update_if (.clk);
    state_intf #(.ID_WID(ID_WID), .STATE_WID(STATE_WID), .UPDATE_WID(UPDATE_WID)) ctrl_if (.clk);

    db_intf #(.KEY_WID(ID_WID), .VALUE_WID(STATE_WID)) db_wr_if (.clk);
    db_intf #(.KEY_WID(ID_WID), .VALUE_WID(STATE_WID)) db_rd_if (.clk);

    // ----------------------------------
    // State logic
    // ----------------------------------
    state_vector_core #(
        .ID_WID ( ID_WID ),
        .SPEC ( SPEC )
    ) i_state_vector_core  ( .* );
    
    // ----------------------------------
    // State data store
    // ----------------------------------
    db_store_array  #(
        .KEY_WID     ( ID_WID ),
        .VALUE_WID   ( STATE_WID ),
        .TRACK_VALID ( 1'b0 )
    ) i_db_store_array (
        .init      ( db_init ),
        .init_done ( db_init_done ),
        .*
    );

    // ----------------------------------
    // Connect interfaces
    // ----------------------------------
    // Control interface
    assign db_ctrl_if.req = db_ctrl_req;
    assign db_ctrl_if.key = db_ctrl_key;
    assign db_ctrl_if.command = db_ctrl_command;
    assign db_ctrl_if.set_value = db_ctrl_set_value;
    assign db_ctrl_rdy = db_ctrl_if.rdy;
    assign db_ctrl_ack = db_ctrl_if.ack;
    assign db_ctrl_status = db_ctrl_if.status;
    assign db_ctrl_get_valid = db_ctrl_if.get_valid;
    assign db_ctrl_get_key = db_ctrl_if.get_key;
    assign db_ctrl_get_value = db_ctrl_if.get_value;

    // Info interface
    assign info_type = info_if._type;
    assign info_subtype = info_if.subtype;
    assign info_size = info_if.size;

    // Update interface (datapath)
    assign update_if.req = update_req;
    assign update_if.ctxt = update_ctxt;
    assign update_if.id = update_id;
    assign update_if.init = update_init;
    assign update_if.update = update_update;
    assign update_rdy = update_if.rdy;
    assign update_ack = update_if.ack;
    assign update_state = update_if.state;
    
    // Update interface (control)
    assign ctrl_if.req = ctrl_req;
    assign ctrl_if.ctxt = ctrl_ctxt;
    assign ctrl_if.id = ctrl_id;
    assign ctrl_if.init = ctrl_init;
    assign ctrl_if.update = ctrl_update;
    assign ctrl_rdy = ctrl_if.rdy;
    assign ctrl_ack = ctrl_if.ack;
    assign ctrl_state = ctrl_if.state;

endmodule : state_vector_sram_wrapper
