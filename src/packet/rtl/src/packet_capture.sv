// Module: packet_capture
//
// Description: Provides register interface for capturing a packet from the
//              data plane and inspecting it in the control plane.
//
//              The packet data carried on a packet interface is written at the
//              dataplane word rate (i.e. quickly) into a memory and then read out
//              register-by-register (i.e. slowly)
module packet_capture #(
    parameter bit  IGNORE_RDY = 0,
    parameter int  PACKET_MEM_SIZE = 16384,
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1,
    parameter bit  SIM__RAM_MODEL = 1
) (
    // Clock/Reset
    input  logic                clk,
    input  logic                srst,

    // Outputs
    output logic                en,

    // AXI-L control interface
    axi4l_intf.peripheral       axil_if,

    // Packet data interface
    packet_intf.rx              packet_if
);

    // -----------------------------
    // Imports
    // -----------------------------
    import packet_pkg::*;
    import packet_capture_reg_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_BYTE_WID = packet_if.DATA_BYTE_WID;
    localparam int  DATA_WID = DATA_BYTE_WID*8;
    localparam int  MTY_WID  = $clog2(DATA_BYTE_WID);
    localparam type MTY_T    = logic[MTY_WID-1:0];

    localparam int  META_WID = packet_if.META_WID;
    localparam int  META_BYTES = META_WID % 8 == 0 ? META_WID / 8 : META_WID / 8 + 1;
    localparam int  META_REGS = META_BYTES % 4 == 0 ? META_BYTES / 4 : META_BYTES / 4 + 1;

    localparam int  PACKET_MEM_DEPTH = PACKET_MEM_SIZE / DATA_BYTE_WID;
    localparam int  PACKET_MEM_ADDR_WID = $clog2(PACKET_MEM_DEPTH);

    localparam int  SIZE_WID = $bits(packet_capture_reg_pkg::fld_status_packet_bytes_t);
    localparam int  MAX_PKT_SIZE = 2**SIZE_WID;

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(packet_if.DATA_BYTE_WID, DATA_BYTE_WID, "packet_if.DATA_BYTE_WID");
        std_pkg::param_check_lt(META_REGS, packet_capture_reg_pkg::COUNT_META, "META_WID");
    end

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [3:0][7:0] reg_t;

    typedef enum logic [2:0] {
        RESET = 0,
        DISABLED = 1,
        READY = 2,
        CAPTURE = 3,
        DONE = 4,
        ERROR = 5
    } state_t;

    // -----------------------------
    // Signals
    // -----------------------------
    state_t state;
    state_t nxt_state;

    logic             mem_init_done;

    logic             status_rd_ack;

    logic             req;
    logic             trigger;
    logic             capture;
    logic             done;
    logic             error;

    fld_status_code_t status_code;
    logic             status_done;
    logic             status_error;

    logic [SIZE_WID-1:0] packet_bytes;

    logic [0:META_BYTES-1][7:0] meta_out;
    logic [META_WID-1:0]        meta;

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf axil_if__control ();
    axi4l_intf axil_if__counts ();
    axi4l_intf axil_if__data ();
    axi4l_intf axil_if__control__clk ();

    packet_capture_reg_intf reg_if ();

    mem_intf #(.ADDR_WID(PACKET_MEM_ADDR_WID), .DATA_WID(DATA_WID)) mem_if__proxy (.clk);
    mem_intf #(.ADDR_WID(PACKET_MEM_ADDR_WID), .DATA_WID(DATA_WID)) mem_if__write (.clk);

    mem_wr_intf #(.ADDR_WID(PACKET_MEM_ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk);
    mem_rd_intf #(.ADDR_WID(PACKET_MEM_ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if__unused (.clk);

    packet_descriptor_intf #(.ADDR_WID (PACKET_MEM_ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) nxt_descriptor_if (.clk, .srst);
    packet_descriptor_intf #(.ADDR_WID (PACKET_MEM_ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) descriptor_if (.clk, .srst);

    packet_event_intf event_if (.clk);
    // ----------------------------------------
    // Packet capture registers
    // ----------------------------------------
    packet_capture_decoder i_packet_capture_decoder (
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
    packet_capture_reg_blk i_packet_capture_reg_blk (
        .axil_if    ( axil_if__control__clk ),
        .reg_blk_if ( reg_if )
    );

    // Report parameterization details
    assign reg_if.info_nxt_v = 1'b1;
    assign reg_if.info_nxt.mem_size = PACKET_MEM_SIZE;
    assign reg_if.info_nxt.meta_width = META_WID;

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
    assign reg_if.status_nxt.packet_bytes = packet_bytes;

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

    // Unpack metadata to registers
    generate
        for (genvar g_reg = 0; g_reg < META_REGS; g_reg++) begin : g__meta_reg
            reg_t meta_reg;
            for (genvar g_reg_byte = 0; g_reg_byte < 4; g_reg_byte++) begin : g__byte
                localparam int byte_idx = g_reg * 4 + g_reg_byte;
                if (byte_idx < META_BYTES) assign meta_reg[g_reg_byte] = meta_out[byte_idx];
                else                       assign meta_reg[g_reg_byte] = 8'h0;
            end : g__byte
            assign reg_if.meta_nxt[g_reg] = meta_reg;
            assign reg_if.meta_nxt_v[g_reg] = done;
        end : g__meta_reg
    endgenerate

    // ----------------------------------------
    // Packet capture FSM
    // ----------------------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        req = 1'b0;
        trigger = 1'b0;
        capture = 1'b0;
        done = 1'b0;
        error = 1'b0;
        case (state)
            RESET : begin
                if (mem_init_done) nxt_state = DISABLED;
            end
            DISABLED: begin
                if (reg_if.control.enable) nxt_state = READY;
            end
            READY: begin
                if (!reg_if.control.enable) nxt_state = DISABLED;
                else if (reg_if.command_wr_evt) begin
                    req = 1'b1;
                    case (reg_if.command.code)
                        COMMAND_CODE_NOP : nxt_state = DONE;
                        COMMAND_CODE_CAPTURE : nxt_state = CAPTURE;
                    endcase
                end
            end
            CAPTURE : begin
                capture = 1'b1;
                if (nxt_descriptor_if.rdy) begin
                    if (descriptor_if.vld) nxt_state = DONE;
                    else                   nxt_state = ERROR;
                end
            end
            DONE : begin
                done = 1'b1;
                nxt_state = READY;
            end
            ERROR : begin
                error = 1'b1;
                nxt_state = READY;
            end
            default: begin
                nxt_state = RESET;
            end
        endcase
    end

    assign descriptor_if.rdy = capture;

    // Provide write descriptor when armed
    assign nxt_descriptor_if.vld = capture;
    assign nxt_descriptor_if.addr = 0;
    assign nxt_descriptor_if.size = PACKET_MEM_SIZE >= 2**SIZE_WID ? 2**SIZE_WID-1 : PACKET_MEM_SIZE;
    assign nxt_descriptor_if.meta = 'x;
    assign nxt_descriptor_if.err = 1'bx;

    // Latch packet context
    always @(posedge clk) begin
        if (descriptor_if.vld && descriptor_if.rdy) begin
            packet_bytes <= descriptor_if.size;
            meta <= descriptor_if.meta;
        end
    end
    assign meta_out = meta;

    // -- Convert state to status code
    initial status_code = STATUS_CODE_RESET;
    always @(posedge clk) begin
        case (state)
            RESET   : status_code <= STATUS_CODE_RESET;
            DISABLED: status_code <= STATUS_CODE_DISABLED;
            CAPTURE : status_code <= STATUS_CODE_BUSY;
            default : status_code <= STATUS_CODE_READY;
        endcase
    end

    // ----------------------------------------
    // Register proxy (for reading packet data)
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
        .SIM__FAST_INIT ( SIM__FAST_INIT ),
        .SIM__RAM_MODEL ( SIM__RAM_MODEL )
    ) i_mem_ram_tdp (
        .mem_if_0 ( mem_if__proxy ),
        .mem_if_1 ( mem_if__write )
    );

    // ----------------------------------------
    // Packet write instance
    // ----------------------------------------
    packet_write     #(
        .IGNORE_RDY   ( IGNORE_RDY ),
        .DROP_ERRORED ( 0 ),
        .MIN_PKT_SIZE ( 0 ),
        .MAX_PKT_SIZE ( PACKET_MEM_SIZE )
    ) i_packet_write  (
        .clk,
        .srst,
        .packet_if,
        .nxt_descriptor_if,
        .descriptor_if,
        .event_if,
        .mem_wr_if,
        .mem_init_done
    );

    mem_sdp_to_sp_adapter i_mem_sdp_to_sp_adapter (
        .mem_wr_if ( mem_wr_if ),
        .mem_rd_if ( mem_rd_if__unused ),
        .mem_if    ( mem_if__write )
    );

    assign mem_rd_if__unused.rst = 1'b0;
    assign mem_rd_if__unused.req = 1'b0;

endmodule : packet_capture
