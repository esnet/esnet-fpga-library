// Module: packet_playback
//
// Description: Provides register interface for injecting a packet from the
//              control plane into the data plane.
//
//              The packet data written register-by-register (i.e. slowly)
//              into a memory and then read out at the dataplane word rate
//              (i.e. quickly) into a packet interface.
module packet_playback #(
    parameter bit  IGNORE_RDY = 0,
    parameter int  MAX_RD_LATENCY = 8,
    parameter int  PACKET_MEM_SIZE = 16384
) (
    // Clock/Reset
    input  logic                clk,
    input  logic                srst,

    // Outputs
    output logic                en,

    // AXI-L control interface
    axi4l_intf.peripheral       axil_if,

    // Packet data interface
    packet_intf.tx              packet_if
);

    // -----------------------------
    // Imports
    // -----------------------------
    import packet_pkg::*;
    import packet_playback_reg_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_BYTE_WID = packet_if.DATA_BYTE_WID;
    localparam int  DATA_WID = DATA_BYTE_WID*8;
    localparam type DATA_T = logic[DATA_BYTE_WID-1:0][7:0];
    localparam int  MTY_WID  = $clog2(DATA_BYTE_WID);
    localparam type MTY_T    = logic[MTY_WID-1:0];

    localparam type META_T = packet_if.META_T;
    localparam int  META_WID = $bits(META_T);
    localparam int  META_BYTES = META_WID % 8 == 0 ? META_WID / 8 : META_WID / 8 + 1;
    localparam int  META_REGS = META_BYTES % 4 == 0 ? META_BYTES / 4 : META_BYTES / 4 + 1;

    localparam int  PACKET_MEM_DEPTH = PACKET_MEM_SIZE / DATA_BYTE_WID;
    localparam int  PACKET_MEM_ADDR_WID = $clog2(PACKET_MEM_DEPTH);
    localparam type PACKET_MEM_ADDR_T = logic[PACKET_MEM_ADDR_WID-1:0];

    localparam int  SIZE_WID = $bits(packet_playback_reg_pkg::fld_config_packet_bytes_t);
    localparam type SIZE_T = logic[SIZE_WID-1:0];
    localparam int  BURST_SIZE_WID = $bits(packet_playback_reg_pkg::fld_config_burst_size_t);
    localparam type BURST_CNT_T = logic[BURST_SIZE_WID-1:0];

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(packet_if.DATA_BYTE_WID, DATA_BYTE_WID, "packet_if.DATA_BYTE_WID");
        std_pkg::param_check_lt(META_REGS, packet_playback_reg_pkg::COUNT_META, "META_WID");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [3:0][7:0] reg_t;

    typedef enum logic [3:0] {
        RESET = 0,
        DISABLED = 1,
        READY = 2,
        SEND_ONE = 3,
        SEND_BURST = 4,
        SEND_CONTINUOUS = 5,
        STOP = 6,
        DONE = 7,
        ERROR = 8,
        TIMEOUT = 9
    } state_t;

    // -----------------------------
    // Signals
    // -----------------------------
    state_t state;
    state_t nxt_state;

    logic             mem_init_done;

    logic             status_rd_ack;

    logic             req;
    logic             send;
    logic             done;
    logic             error;
    logic             timeout;

    fld_status_code_t status_code;
    logic             status_done;
    logic             status_error;
    logic             status_timeout;

    SIZE_T            packet_bytes;
    BURST_CNT_T       burst_size_m1;
    BURST_CNT_T       burst_cnt;

    logic [0:META_BYTES-1][7:0] meta_in;
    META_T            meta;

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf axil_if__control ();
    axi4l_intf axil_if__counts ();
    axi4l_intf axil_if__data ();
    axi4l_intf axil_if__control__clk ();

    packet_playback_reg_intf reg_if ();

    mem_intf #(.ADDR_T(PACKET_MEM_ADDR_T), .DATA_T(DATA_T)) mem_if__proxy (.clk(clk));
    mem_intf #(.ADDR_T(PACKET_MEM_ADDR_T), .DATA_T(DATA_T)) mem_if__read (.clk(clk));

    mem_wr_intf #(.ADDR_WID(PACKET_MEM_ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if__unused (.clk(clk));
    mem_rd_intf #(.ADDR_WID(PACKET_MEM_ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(clk));

    packet_descriptor_intf #(.ADDR_T (PACKET_MEM_ADDR_T), .META_T(META_T), .SIZE_T(SIZE_T)) descriptor_if (.clk);
    packet_event_intf event_if (.clk);
    // ----------------------------------------
    // Packet playback registers
    // ----------------------------------------
    packet_playback_decoder i_packet_playback_decoder (
        .axil_if         ( axil_if ),
        .control_axil_if ( axil_if__control ),
        .counts_axil_if  ( axil_if__counts ),
        .data_axil_if    ( axil_if__data )
    );

    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if__control ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__control__clk )
    );

    // Registers
    packet_playback_reg_blk i_packet_playback_reg_blk (
        .axil_if    ( axil_if__control__clk ),
        .reg_blk_if ( reg_if )
    );

    // Report parameterization details
    assign reg_if.info_nxt_v = 1'b1;
    assign reg_if.info_nxt.mem_size = PACKET_MEM_SIZE;
    assign reg_if.info_nxt.meta_width = $bits(META_T);

    // Export enable
    initial en = 1'b0;
    always @(posedge clk) begin
        if (srst) en <= 1'b0;
        else      en <= reg_if.control.enable;
    end

    // Report state machine status to regmap
    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.code  = status_code;
    assign reg_if.status_nxt.done  = status_done;
    assign reg_if.status_nxt.error = status_error;
    assign reg_if.status_nxt.timeout = status_timeout;

    // Status read event
    assign status_rd_ack = reg_if.status_rd_evt;

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

    // Pack metadata from registers
    generate
        for (genvar g_reg = 0; g_reg < META_REGS; g_reg++) begin : g__meta_reg
            reg_t meta_reg;
            assign meta_reg = reg_if.meta[g_reg];
            for (genvar g_reg_byte = 0; g_reg_byte < 4; g_reg_byte++) begin : g__byte
                localparam int byte_idx = (g_reg * 4 + g_reg_byte);
                if (byte_idx < META_BYTES) assign meta_in[byte_idx] = meta_reg[g_reg_byte];
                else                       assign meta_in[byte_idx] = 8'h0;
            end : g__byte
        end : g__meta_reg
    endgenerate

    // ----------------------------------------
    // Packet playback FSM
    // ----------------------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        req = 1'b0;
        send = 1'b0;
        done = 1'b0;
        error = 1'b0;
        timeout = 1'b0;
        case (state)
            RESET : begin
                if (mem_init_done) nxt_state = DISABLED;
            end
            DISABLED : begin
                if (reg_if.control.enable) nxt_state = READY;
            end
            READY: begin
                if (!reg_if.control.enable) nxt_state = DISABLED;
                else if (reg_if.command_wr_evt) begin
                    req = 1'b1;
                    case (reg_if.command.code)
                        COMMAND_CODE_NOP : nxt_state = DONE;
                        COMMAND_CODE_SEND_ONE : nxt_state = SEND_ONE;
                        COMMAND_CODE_SEND_BURST : nxt_state = SEND_BURST;
                        COMMAND_CODE_SEND_CONTINUOUS : nxt_state = SEND_CONTINUOUS;
                    endcase
                end
            end
            SEND_ONE : begin
                send = 1'b1;
                if (descriptor_if.rdy) nxt_state = STOP;
            end
            SEND_BURST : begin
                send = 1'b1;
                if (descriptor_if.rdy) begin
                    if (burst_cnt == burst_size_m1) nxt_state = STOP;
                end
            end
            SEND_CONTINUOUS : begin
                send = 1'b1;
                if (reg_if.command_wr_evt) begin
                    case (reg_if.command.code)
                        COMMAND_CODE_STOP : nxt_state = STOP;
                    endcase
                end
            end
            STOP: begin
                if (descriptor_if.rdy) nxt_state = DONE;
            end
            DONE : begin
                done = 1'b1;
                nxt_state = READY;
            end
            ERROR : begin
                error = 1'b1;
                nxt_state = READY;
            end
            TIMEOUT : begin
                timeout = 1'b1;
                nxt_state = READY;
            end
            default: begin
                nxt_state = RESET;
            end
        endcase
    end

    // Latch packet context
    always @(posedge clk) begin
        if (req) begin
            packet_bytes <= reg_if._config.packet_bytes;
            burst_size_m1 <= reg_if._config.burst_size == 0 ? 0 : reg_if._config.burst_size - 1;
            meta <= meta_in;
        end
    end

    // Track bursts
    always_ff @(posedge clk) begin
        if (req) burst_cnt <= '0;
        else if (send && descriptor_if.rdy) burst_cnt <= burst_cnt + 1;
    end

    assign descriptor_if.valid = send;
    assign descriptor_if.addr = '0;
    assign descriptor_if.size = packet_bytes;
    assign descriptor_if.meta = meta;

    // -- Convert state to status code
    initial status_code = STATUS_CODE_RESET;
    always @(posedge clk) begin
        case (state)
            RESET           : status_code <= STATUS_CODE_RESET;
            DISABLED        : status_code <= STATUS_CODE_DISABLED;
            SEND_ONE,
            SEND_BURST,
            SEND_CONTINUOUS : status_code <= STATUS_CODE_BUSY;
            default         : status_code <= STATUS_CODE_READY;
        endcase
    end

    // ----------------------------------------
    // Register proxy (for writing packet data)
    // ----------------------------------------
    mem_proxy       #(
        .ACCESS_TYPE ( mem_pkg::ACCESS_READ_WRITE ),
        .MEM_TYPE    ( mem_pkg::MEM_TYPE_SRAM ),
        .BIGENDIAN   ( 1 ) // Use network byte order
    ) i_mem_proxy    (
        .clk,
        .srst,
        .init_done   ( mem_init_done ),
        .axil_if     ( axil_if__data ),
        .mem_if      ( mem_if__proxy )
    );

    // ----------------------------------------
    // Packet data RAM instance
    // ----------------------------------------
    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID  : PACKET_MEM_ADDR_WID,
        DATA_WID  : DATA_WID,
        ASYNC     : 0,
        RESET_FSM : 1,
        OPT_MODE  : mem_pkg::OPT_MODE_DEFAULT
    };
    localparam int PACKET_RAM_RD_LATENCY = mem_pkg::get_rd_latency(MEM_SPEC);

    mem_ram_tdp #(
        .SPEC    ( MEM_SPEC ),
        .SIM__FAST_INIT ( 1 ),
        .SIM__RAM_MODEL ( 0 )
    ) i_mem_ram_tdp (
        .mem_if_0 ( mem_if__proxy ),
        .mem_if_1 ( mem_if__read )
    );

    // ----------------------------------------
    // Packet read instance
    // ----------------------------------------
    packet_read #(
        .IGNORE_RDY     ( IGNORE_RDY ),
        .MAX_RD_LATENCY ( PACKET_RAM_RD_LATENCY )
    ) i_packet_read (
        .clk,
        .srst,
        .packet_if     ( packet_if ),
        .descriptor_if ( descriptor_if ),
        .event_if      ( event_if ),
        .mem_rd_if     ( mem_rd_if )
    );

    mem_sdp_to_sp_adapter i_mem_sdp_to_sp_adapter (
        .mem_wr_if ( mem_wr_if__unused),
        .mem_rd_if ( mem_rd_if ),
        .mem_if    ( mem_if__read )
    );

    assign mem_wr_if__unused.rst = 1'b0;
    assign mem_wr_if__unused.en  = 1'b0;
    assign mem_wr_if__unused.req = 1'b0;

endmodule : packet_playback
