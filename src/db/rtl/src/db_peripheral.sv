module db_peripheral #(
    parameter int  TIMEOUT_CYCLES = 0
) (
    // Clock/reset
    input  logic       clk,
    input  logic       srst,

    // Control interface (from controller)
    db_ctrl_intf.peripheral ctrl_if,

    // Database interface
    output logic       init,
    input  logic       init_done,
    
    // Database write interface
    db_intf.requester  wr_if,

    // Database read interface
    db_intf.requester  rd_if
);
 
    // -----------------------------
    // Imports
    // -----------------------------
    import db_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int INIT_DONE_DEBOUNCE_CNT = 8;

    // Check
    initial begin
        std_pkg::param_check(wr_if.KEY_WID,    ctrl_if.KEY_WID,   "wr_if.KEY_WID");
        std_pkg::param_check(wr_if.VALUE_WID,  ctrl_if.VALUE_WID, "wr_if.VALUE_WID");
        std_pkg::param_check(rd_if.KEY_WID,    ctrl_if.KEY_WID,   "rd_if.KEY_WID");
        std_pkg::param_check(rd_if.VALUE_WID,  ctrl_if.VALUE_WID, "rd_if.VALUE_WID");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic [3:0] {
        RESET,
        IDLE,
        CLEAR,
        RD,
        RMW,
        WR,
        CLEAR_PENDING,
        RD_PENDING,
        WR_PENDING,
        DONE,
        ERROR,
        TIMEOUT
    } state_t;

    // -----------------------------
    // Signals
    // -----------------------------
    state_t state;
    state_t nxt_state;

    logic    ctrl_rdy;
    logic    ctrl_ack;
    status_t ctrl_status;

    logic wr_req;
    logic rd_req;

    logic timeout;
    logic reset_timer;
    logic inc_timer;

    logic init_done__debounced;

    // -----------------------------
    // Logic
    // -----------------------------
    // Control FSM
    initial state = RESET;
    always @(posedge clk) begin
        if (srst)         state <= RESET;
        else if (timeout) state <= TIMEOUT;
        else              state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        reset_timer = 1'b0;
        inc_timer = 1'b0;
        ctrl_rdy = 1'b0;
        ctrl_ack = 1'b0;
        ctrl_status = STATUS_ERROR;
        init = 1'b0;
        wr_req = 1'b0;
        rd_req = 1'b0;
        case (state)
            RESET : begin
                if (init_done__debounced) nxt_state = IDLE;
            end
            IDLE : begin
                reset_timer = 1'b1;
                ctrl_rdy = 1'b1;
                if (ctrl_if.req) begin
                    case (ctrl_if.command)
                        COMMAND_CLEAR : begin
                            nxt_state = CLEAR;
                        end
                        COMMAND_GET : begin
                            nxt_state = RD;
                        end
                        COMMAND_GET_NEXT : begin
                            nxt_state = RD;
                        end
                        COMMAND_UNSET : begin 
                            nxt_state = RMW;
                        end
                        COMMAND_UNSET_NEXT : begin
                            nxt_state = RMW;
                        end
                        COMMAND_REPLACE : begin
                            nxt_state = RMW;
                        end
                        COMMAND_SET : begin
                            nxt_state = WR;
                        end
                        COMMAND_NOP : begin
                            nxt_state = DONE;
                        end
                        default : begin
                            nxt_state = ERROR;
                        end
                    endcase
                end
            end
            CLEAR : begin
                inc_timer = 1'b1;
                init = 1'b1;
                nxt_state = CLEAR_PENDING;
            end
            RD : begin
                inc_timer = 1'b1;
                rd_req = 1'b1;
                if (rd_if.rdy) nxt_state = RD_PENDING;
            end
            RMW : begin
                inc_timer = 1'b1;
                wr_req = 1'b1;
                rd_req = 1'b1;
                if (wr_if.rdy && rd_if.rdy) nxt_state = RD_PENDING;
            end
            WR : begin
                inc_timer = 1'b1;
                wr_req = 1'b1;
                if (wr_if.rdy) nxt_state = WR_PENDING;
            end
            CLEAR_PENDING : begin
                inc_timer = 1'b1;
                if (init_done__debounced) nxt_state = DONE;
            end
            RD_PENDING : begin
                inc_timer = 1'b1;
                if (rd_if.ack) begin
                    if (rd_if.error)  nxt_state = ERROR;
                    else              nxt_state = DONE;
                end
            end
            WR_PENDING : begin
                inc_timer = 1'b1;
                if (wr_if.ack) begin
                    if (wr_if.error)  nxt_state = ERROR;
                    else              nxt_state = DONE;
                end
            end
            DONE : begin
                ctrl_ack = 1'b1;
                ctrl_status = STATUS_OK;
                nxt_state = IDLE;
            end
            ERROR : begin
                ctrl_ack = 1'b1;
                ctrl_status = STATUS_ERROR;
                nxt_state = IDLE;
            end
            TIMEOUT : begin
                ctrl_ack = 1'b1;
                ctrl_status = STATUS_TIMEOUT;
                nxt_state = IDLE;
            end
            default : begin
                nxt_state = ERROR;
            end
        endcase
    end

    // Drive control response
    assign ctrl_if.rdy = ctrl_rdy;
    assign ctrl_if.ack = ctrl_ack;
    assign ctrl_if.status = ctrl_status;

    // Drive write/read requests
    always_comb begin
        if (state == RMW) begin
            wr_if.req = rd_if.rdy;
            rd_if.req = wr_if.rdy;
        end else begin
            wr_if.req = wr_req;
            rd_if.req = rd_req;
        end
    end

    // Latch request data
    always_ff @(posedge clk) begin
        if (ctrl_if.req && ctrl_if.rdy) begin
            wr_if.key <= ctrl_if.key;
            rd_if.key <= ctrl_if.key;
            if (ctrl_if.command == COMMAND_UNSET || ctrl_if.command == COMMAND_UNSET_NEXT) begin
                wr_if.valid <= 1'b0;
                wr_if.value <= '0;
            end else begin
                wr_if.valid <= 1'b1;
                wr_if.value <= ctrl_if.set_value;
            end
            if (ctrl_if.command == COMMAND_UNSET_NEXT ) begin
                wr_if.next <= 1'b1;
            end else begin
                wr_if.next <= 1'b0;
            end
            if (ctrl_if.command == COMMAND_GET_NEXT || ctrl_if.command == COMMAND_UNSET_NEXT) begin
                rd_if.next <= 1'b1;
            end else begin
                rd_if.next <= 1'b0;
            end
        end
    end

    // Latch response data
    always_ff @(posedge clk) begin
        if (rd_if.ack) begin
            ctrl_if.get_valid <= rd_if.valid;
            ctrl_if.get_value <= rd_if.value;
            ctrl_if.get_key <= rd_if.next_key;
        end
    end

    // Implement (optional) init_done debouncing to account for possible pipeline delays
    generate
        if (INIT_DONE_DEBOUNCE_CNT > 0) begin : g__init_done_debounce
            localparam int INIT_DONE_CNT_WID = $clog2(INIT_DONE_DEBOUNCE_CNT);
            logic [INIT_DONE_CNT_WID-1:0] init_done_cnt;
            initial init_done_cnt = 0;
            always @(posedge clk) begin
                if (srst || init) init_done_cnt <= 0;
                else if (init_done_cnt < INIT_DONE_DEBOUNCE_CNT-1) begin
                    if (init_done) init_done_cnt <= init_done_cnt + 1;
                    else           init_done_cnt <= 0;
                end
            end
            assign init_done__debounced = (init_done_cnt == INIT_DONE_DEBOUNCE_CNT-1);
        end : g__init_done_debounce
        else begin : g__init_done_no_debounce
            assign init_done__debounced = init_done;
        end : g__init_done_no_debounce
    endgenerate
    
    // Implement (optional) timeout logic
    generate
        if (TIMEOUT_CYCLES > 0) begin : g__timeout
            localparam int TIMEOUT_WID = $clog2(TIMEOUT_CYCLES);
            logic [TIMEOUT_WID-1:0] timer;

            initial timer = 0;
            always @(posedge clk) begin
                if (reset_timer) timer <= 0;
                else if (inc_timer) timer <= timer + 1;
            end
            assign timeout = (timer == TIMEOUT_CYCLES-1);
        end : g__timeout
        else begin : g__no_timeout
            assign timeout = 1'b0;
        end : g__no_timeout
    endgenerate

endmodule : db_peripheral
