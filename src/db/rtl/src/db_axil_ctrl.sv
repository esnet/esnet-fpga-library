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
module db_axil_ctrl #(
    parameter type KEY_T   = logic [7:0],
    parameter type VALUE_T = logic [31:0]
)(
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    input  logic               init_done,

    // AXI4-Lite control interface
    axi4l_intf.peripheral      axil_if,

    // Block control
    output logic               ctrl_reset,
    output logic               ctrl_en,

    // Block monitoring
    input  logic               reset_mon,
    input  logic               en_mon,
    input  logic               ready_mon,

    // Info
    db_info_intf.controller    info_if,

    // Database control interface
    db_ctrl_intf.controller    ctrl_if,

    // Status
    db_status_intf.controller  status_if
);
    // -----------------------------
    // Imports
    // -----------------------------
    import db_pkg::*;
    import db_reg_pkg::*;

    // -----------------------------
    // Functions
    // -----------------------------
    // -- RTL to regmap translation (database type)
    function automatic fld_info_db_type_t getRegFromType(input type_t db_type);
        case (db_type)
            DB_TYPE_CACHE : return INFO_DB_TYPE_CACHE;
            DB_TYPE_STATE : return INFO_DB_TYPE_STATE;
            default       : return INFO_DB_TYPE_UNSPECIFIED;
        endcase
    endfunction
    // -- Regmap to RTL translation (command)
    function automatic command_t getCommandFromReg(input fld_command_code_t command_code);
        case (command_code)
            COMMAND_CODE_GET      : return COMMAND_GET;
            COMMAND_CODE_GET_NEXT : return COMMAND_GET_NEXT;
            COMMAND_CODE_SET      : return COMMAND_SET;
            COMMAND_CODE_UNSET    : return COMMAND_UNSET;
            COMMAND_CODE_REPLACE  : return COMMAND_REPLACE;
            COMMAND_CODE_CLEAR    : return COMMAND_CLEAR;
            default               : return COMMAND_NOP;
        endcase
    endfunction

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int KEY_BITS = $bits(KEY_T);
    localparam int VALUE_BITS = $bits(VALUE_T);

    localparam int KEY_BYTES = KEY_BITS % 8 == 0 ? KEY_BITS / 8 : KEY_BITS / 8 + 1;
    localparam int VALUE_BYTES = VALUE_BITS % 8 == 0 ? VALUE_BITS / 8 : VALUE_BITS / 8 + 1;

    // Determine depth of KEY/VALUE register arrays
    localparam int KEY_REGS = KEY_BYTES % 4 == 0 ? KEY_BYTES / 4 : KEY_BYTES / 4 + 1;
    localparam int VALUE_REGS = VALUE_BYTES % 4 == 0 ? VALUE_BYTES / 4 : VALUE_BYTES / 4 + 1;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [3:0][7:0] reg_t;
    typedef logic [0:KEY_BYTES-1] key_bytes;
    typedef logic [0:VALUE_BYTES-1] value_bytes;

    typedef enum logic [2:0] {
        RESET   = 0,
        IDLE    = 1,
        REQ     = 2,
        BUSY    = 3,
        DONE    = 4,
        ERROR   = 5,
        TIMEOUT = 6
    } state_t;

    // -----------------------------
    // Local signals
    // -----------------------------
    fld_status_code_t status_code;
    logic             status_done;
    logic             status_error;
    logic             status_timeout;

    logic             status_rd_ack;

    logic             command_evt;

    logic [0:KEY_BYTES-1]  [7:0] key_in;
    logic [0:VALUE_BYTES-1][7:0] set_value_in;
    logic [0:VALUE_BYTES-1][7:0] get_value_bytes;
    logic [0:KEY_BYTES-1]  [7:0] get_key_bytes;

    logic      req;

    state_t    state;
    state_t    nxt_state;

    logic      done;
    logic      error;
    logic      timeout;

    logic [7:0] state_mon_in;
    logic [7:0] state_mon_out;

    // -----------------------------
    // Local interfaces
    // -----------------------------
    db_reg_intf reg_if ();

    axi4l_intf #() axil_if__clk ();

    // ----------------------------------------
    // Database register block
    // ----------------------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    // Registers
    db_reg_blk i_db_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    // Assign static INFO register values
    assign reg_if.info_nxt_v = 1'b1;
    assign reg_if.info_nxt.db_type = getRegFromType(info_if._type);
    assign reg_if.info_nxt.db_subtype = info_if.subtype;

    assign reg_if.info_size_nxt_v = 1'b1;
    assign reg_if.info_size_nxt = info_if.size;

    assign reg_if.info_key_nxt_v = 1'b1;
    assign reg_if.info_key_nxt.bits = KEY_BITS;
    assign reg_if.info_key_nxt.bytes = KEY_BYTES;
    assign reg_if.info_key_nxt.regs = KEY_REGS;

    assign reg_if.info_value_nxt_v = 1'b1;
    assign reg_if.info_value_nxt.bits = VALUE_BITS;
    assign reg_if.info_value_nxt.bytes = VALUE_BYTES;
    assign reg_if.info_value_nxt.regs = VALUE_REGS;

    assign reg_if.status_fill_nxt_v = 1'b1;
    assign reg_if.status_fill_nxt = status_if.fill;

    // Report state machine status to regmap
    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.code  = status_code;
    assign reg_if.status_nxt.done  = status_done;
    assign reg_if.status_nxt.error = status_error;
    assign reg_if.status_nxt.timeout = status_timeout;

    // Status read event
    assign status_rd_ack = reg_if.status_rd_evt;

    // Command
    assign command_evt = reg_if.command_wr_evt;

    // Pack key from reg
    generate
        for (genvar g_reg = 0; g_reg < KEY_REGS; g_reg++) begin : g__key_reg
            reg_t key_reg;
            assign key_reg = reg_if.key[g_reg];
            for (genvar g_reg_byte = 0; g_reg_byte < 4; g_reg_byte++) begin : g__byte
                localparam int byte_idx = g_reg * 4 + g_reg_byte;
                if (byte_idx < KEY_BYTES) assign key_in[byte_idx] = key_reg[g_reg_byte];
            end : g__byte
        end : g__key_reg
    endgenerate

    // Pack value from reg
    generate
        for (genvar g_reg = 0; g_reg < VALUE_REGS; g_reg++) begin : g__set_value_reg
            reg_t value_reg;
            assign value_reg = reg_if.set_value[g_reg];
            for (genvar g_reg_byte = 0; g_reg_byte < 4; g_reg_byte++) begin : g__byte
                localparam int byte_idx = g_reg * 4 + g_reg_byte;
                if (byte_idx < VALUE_BYTES) assign set_value_in[byte_idx] = value_reg[g_reg_byte];
            end : g__byte
        end : g__set_value_reg
    endgenerate

    // ----------------------------------------
    // Standard block control/monitoring
    // ----------------------------------------
    std_block_control i_std_block_control (
        .ctrl_clk       ( axil_if.aclk ),
        .ctrl_reset_in  ( reg_if.blk_control.reset ),
        .ctrl_enable_in ( reg_if.blk_control.enable ),
        .blk_clk        ( clk ),
        .blk_reset_out  ( ctrl_reset ),
        .blk_enable_out ( ctrl_en )
    );

    std_block_monitor i_std_block_monitor (
        .blk_clk             ( clk ),
        .blk_reset_mon_in    ( reset_mon ),
        .blk_enable_mon_in   ( en_mon ),
        .blk_ready_mon_in    ( ready_mon ),
        .blk_state_mon_in    ( state_mon_in ),
        .ctrl_clk            ( axil_if.aclk ),
        .ctrl_reset_mon_out  ( reg_if.blk_monitor_nxt.reset_mon ),
        .ctrl_enable_mon_out ( reg_if.blk_monitor_nxt.enable_mon ),
        .ctrl_ready_mon_out  ( reg_if.blk_monitor_nxt.ready_mon ),
        .ctrl_state_mon_out  ( state_mon_out )
    );

    assign state_mon_in = {'0, state};
    assign reg_if.blk_monitor_nxt.state_mon = fld_blk_monitor_state_mon_t'(state_mon_out);

    // ----------------------------------------
    // Logic
    // ----------------------------------------
    // Latch request
    initial req = 1'b0;
    always @(posedge clk) begin
        if (srst)                            req <= 1'b0;
        else if (command_evt)                req <= 1'b1;
        else if (ctrl_if.req && ctrl_if.rdy) req <= 1'b0;
    end

    // Latch command code
    initial ctrl_if.command = COMMAND_NOP;
    always @(posedge clk) begin
        if (command_evt) ctrl_if.command <= getCommandFromReg(reg_if.command.code);
    end

    // Latch key
    initial ctrl_if.key = 0;
    always @(posedge clk) if (command_evt) ctrl_if.key <= key_in;

    // Latch set value
    initial ctrl_if.set_value = 0;
    always @(posedge clk) if (command_evt) ctrl_if.set_value <= set_value_in;

    // Transaction state machine
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        ctrl_if.req = 1'b0;
        done = 1'b0;
        error = 1'b0;
        timeout = 1'b0;
        case (state)
            RESET : begin
                if (init_done) nxt_state = IDLE;
            end
            IDLE : begin
                if (req) nxt_state = REQ;
            end
            REQ : begin
                ctrl_if.req = 1'b1;
                if (ctrl_if.rdy) nxt_state = BUSY;
            end
            BUSY : begin
                if (ctrl_if.ack) begin
                    if (ctrl_if.status == STATUS_ERROR) nxt_state = ERROR;
                    else if (ctrl_if.status == STATUS_TIMEOUT) nxt_state = TIMEOUT;
                    else nxt_state = DONE;
                end
            end
            DONE: begin
                done = 1'b1;
                nxt_state = IDLE;
            end
            TIMEOUT : begin
                timeout = 1'b1;
                nxt_state = IDLE;
            end
            default : begin
                error = 1'b1;
                nxt_state = IDLE;
            end
        endcase
    end

    // Return response
    // -- Latch presence
    assign reg_if.get_valid_nxt_v = ctrl_if.ack;
    assign reg_if.get_valid_nxt.value = ctrl_if.valid;

    // -- Unpack value to registers
    assign get_value_bytes = ctrl_if.get_value;
    generate
        for (genvar g_reg = 0; g_reg < VALUE_REGS; g_reg++) begin : g__get_value_reg
            reg_t reg_value;
            for (genvar g_reg_byte = 0; g_reg_byte < 4; g_reg_byte++) begin
                localparam int byte_idx = g_reg * 4 + g_reg_byte;
                if (byte_idx < VALUE_BYTES) assign reg_value[g_reg_byte] = get_value_bytes[byte_idx];
                else                        assign reg_value[g_reg_byte] = '0;
            end
            assign reg_if.get_value_nxt_v[g_reg] = ctrl_if.ack;
            assign reg_if.get_value_nxt[g_reg] = reg_value;
        end : g__get_value_reg
        for (genvar g_reg = VALUE_REGS; g_reg < COUNT_GET_VALUE; g_reg++) begin : g__get_value_reg_tieoff
            assign reg_if.get_value_nxt_v[g_reg] = 1'b0;
            assign reg_if.get_value_nxt[g_reg] = '0;
        end : g__get_value_reg_tieoff
    endgenerate

    // -- Unpack value to registers
    generate
        for (genvar g_reg = 0; g_reg < KEY_REGS; g_reg++) begin : g__get_key_reg
            reg_t reg_key;
            for (genvar g_reg_byte = 0; g_reg_byte < 4; g_reg_byte++) begin
                localparam int byte_idx = g_reg * 4 + g_reg_byte;
                if (byte_idx < KEY_BYTES) assign reg_key[g_reg_byte] = get_key_bytes[byte_idx];
                else                      assign reg_key[g_reg_byte] = '0;
            end
            assign reg_if.get_key_nxt_v[g_reg] = ctrl_if.ack;
            assign reg_if.get_key_nxt[g_reg] = reg_key;
        end : g__get_key_reg
        for (genvar g_reg = KEY_REGS; g_reg < COUNT_GET_KEY; g_reg++) begin : g__get_key_reg_tieoff
            assign reg_if.get_key_nxt_v[g_reg] = 1'b0;
            assign reg_if.get_key_nxt[g_reg] = '0;
        end : g__get_key_reg_tieoff
    endgenerate

    // -- Convert state to status code
    initial status_code = STATUS_CODE_RESET;
    always @(posedge clk) begin
        case (state)
            RESET   : status_code <= STATUS_CODE_RESET;
            REQ,
            BUSY    : status_code <= STATUS_CODE_BUSY;
            default : status_code <= STATUS_CODE_READY;
        endcase
    end

    // -- Maintain `done` flag
    initial status_done = 1'b0;
    always @(posedge clk) begin
        if (srst)      status_done <= 1'b0;
        else if (done) status_done <= 1'b1;
        else if (req)  status_done <= 1'b0;
        else if (status_rd_ack && reg_if.status.done) status_done <= 1'b0;
    end

    // -- Maintain `error` flag
    initial status_error = 1'b0;
    always @(posedge clk) begin
        if (srst)       status_error <= 1'b0;
        else if (error) status_error <= 1'b1;
        else if (req)   status_error <= 1'b0;
        else if (status_rd_ack && reg_if.status.error) status_error <= 1'b0;
    end

    // -- Maintain `timeout` flag
    initial status_timeout = 1'b0;
    always @(posedge clk) begin
        if (srst)         status_timeout <= 1'b0;
        else if (timeout) status_timeout <= 1'b1;
        else if (req)     status_timeout <= 1'b0;
        else if (status_rd_ack && reg_if.status.timeout) status_timeout <= 1'b0;
    end

endmodule : db_axil_ctrl
