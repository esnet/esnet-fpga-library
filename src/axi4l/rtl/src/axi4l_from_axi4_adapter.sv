// =============================================================================
// AXI4 to AXI4-Lite converter
//
// Converts a wide AXI4 peripheral port to a 32-bit AXI4-L controller port.
// Intended for register window use: only single-beat (AxLEN=0), naturally
// aligned, ≤4-byte transactions are expected from the QDMA BAR.
//
// Byte lane selection:
//   The AXI4 data bus is DATA_BYTE_WID bytes wide.  AxADDR[OFFSET_WID-1:2]
//   selects which 32-bit word within the beat carries the active data.
//   WDATA and WSTRB are extracted from the appropriate lane; RDATA is
//   placed on the correct lane with all others zero-filled.
//
// Restrictions:
//   - Only single-beat bursts (AxLEN=0) are accepted.  Multi-beat bursts
//     are rejected with SLVERR.
//   - AXI4-L target is 32-bit (DATA_BYTE_WID=4).
//   - Write and read channels are processed independently (no ordering
//     enforcement between concurrent AW and AR).
//   - ID and USER fields from AXI4 are captured and returned on the
//     response channel but are otherwise unused.
// =============================================================================
module axi4l_from_axi4_adapter
    import axi4_pkg::*;
#(
    parameter int DATA_BYTE_WID = 64,  // AXI4 bus width in bytes
    parameter int ADDR_WID      = 64,
    parameter int ID_WID        = 1,
    parameter int USER_WID      = 1,
    // Derived — do not override
    parameter int DATA_WID      = DATA_BYTE_WID * 8,
    parameter int OFFSET_WID    = $clog2(DATA_BYTE_WID)
) (
    input logic aclk,
    input logic aresetn,

    // AXI4 peripheral port (from wide controller — e.g. NoC/QDMA)
    axi4_intf.peripheral  axi4_if,

    // AXI4-L controller port (to 32-bit register peripheral)
    axi4l_intf.controller axi4l_if
);
    import axi4l_pkg::*;

    // -------------------------------------------------------------------------
    // Localparams
    // -------------------------------------------------------------------------
    localparam int AXI4L_BYTE_WID = 4;
    localparam int AXI4L_DATA_WID = 32;
    localparam int AXI4L_ADDR_WID = axi4l_if.ADDR_WID;

    localparam int WORDS_PER_BEAT = DATA_BYTE_WID / AXI4L_BYTE_WID;
    localparam int WORD_SEL_WID   = $clog2(WORDS_PER_BEAT);

    // =========================================================================
    // Write path
    // =========================================================================
    typedef enum logic [1:0] {
        WR_IDLE,   // waiting for AW
        WR_DATA,   // AW accepted, waiting for W
        WR_AXIL,   // W accepted, issuing to AXI4-L, waiting for B
        WR_RESP    // AXI4-L B received, driving AXI4 B
    } wr_state_t;

    wr_state_t wr_state;
    wr_state_t wr_nxt_state;

    logic [ID_WID-1:0]         wr_id_q;
    logic [ADDR_WID-1:0]       wr_addr_q;
    logic [2:0]                wr_prot_q;
    logic [WORD_SEL_WID-1:0]   wr_word_q;
    logic                      wr_multi_beat_q;
    logic [AXI4L_DATA_WID-1:0] wr_data_q;
    logic [AXI4L_BYTE_WID-1:0] wr_strb_q;
    logic [1:0]                wr_resp_q;

    // Synchronous state register
    initial wr_state = WR_IDLE;
    always @(posedge aclk) begin
        if (!aresetn) wr_state <= WR_IDLE;
        else          wr_state <= wr_nxt_state;
    end

    // Registered context capture
    always_ff @(posedge aclk) begin
        case (wr_state)
            WR_IDLE: if (axi4_if.awvalid) begin
                wr_id_q         <= axi4_if.awid;
                wr_addr_q       <= axi4_if.awaddr;
                wr_prot_q       <= axi4_if.awprot;
                wr_word_q       <= axi4_if.awaddr[OFFSET_WID-1:2];
                wr_multi_beat_q <= (axi4_if.awlen != 8'h0);
            end
            WR_DATA: if (axi4_if.wvalid) begin
                wr_data_q <= axi4_if.wdata[wr_word_q*AXI4L_BYTE_WID +: AXI4L_BYTE_WID];
                wr_strb_q <= axi4_if.wstrb[wr_word_q*AXI4L_BYTE_WID +: AXI4L_BYTE_WID];
                if (wr_multi_beat_q) wr_resp_q <= 2'b10; // SLVERR
            end
            WR_AXIL: if (axi4l_if.bvalid) begin
                wr_resp_q <= axi4l_if.bresp;
            end
            default: ;
        endcase
    end

    // Combinational next-state and output
    always_comb begin
        wr_nxt_state = wr_state;
        case (wr_state)
            WR_IDLE: if (axi4_if.awvalid)  wr_nxt_state = WR_DATA;
            WR_DATA: if (axi4_if.wvalid)   wr_nxt_state = wr_multi_beat_q ? WR_RESP : WR_AXIL;
            WR_AXIL: if (axi4l_if.bvalid)  wr_nxt_state = WR_RESP;
            WR_RESP: if (axi4_if.bready)   wr_nxt_state = WR_IDLE;
            default:                        wr_nxt_state = WR_IDLE;
        endcase
    end

    // AXI4 write response outputs
    assign axi4_if.awready = (wr_state == WR_IDLE);
    assign axi4_if.wready  = (wr_state == WR_DATA);
    assign axi4_if.bvalid  = (wr_state == WR_RESP);
    assign axi4_if.bid     = wr_id_q;
    assign axi4_if.bresp   = wr_resp_q;
    assign axi4_if.buser   = '0;

    // AXI4-L write outputs
    assign axi4l_if.awvalid = (wr_state == WR_AXIL);
    assign axi4l_if.awaddr  = AXI4L_ADDR_WID'(wr_addr_q & ~ADDR_WID'('h3));
    assign axi4l_if.awprot  = wr_prot_q;
    assign axi4l_if.wvalid  = (wr_state == WR_AXIL);
    assign axi4l_if.wdata   = wr_data_q;
    assign axi4l_if.wstrb   = wr_strb_q;
    assign axi4l_if.bready  = (wr_state == WR_AXIL);

    // =========================================================================
    // Read path
    // =========================================================================
    typedef enum logic [1:0] {
        RD_IDLE,   // waiting for AR
        RD_AXIL,   // AR accepted, issuing to AXI4-L, waiting for R
        RD_RESP    // AXI4-L R received, driving AXI4 R
    } rd_state_t;

    rd_state_t rd_state;
    rd_state_t rd_nxt_state;

    logic [ID_WID-1:0]         rd_id_q;
    logic [ADDR_WID-1:0]       rd_addr_q;
    logic [2:0]                rd_prot_q;
    logic [WORD_SEL_WID-1:0]   rd_word_q;
    logic [AXI4L_DATA_WID-1:0] rd_data_q;
    logic [1:0]                rd_resp_q;

    // Synchronous state register
    initial rd_state = RD_IDLE;
    always @(posedge aclk) begin
        if (!aresetn) rd_state <= RD_IDLE;
        else          rd_state <= rd_nxt_state;
    end

    // Registered context capture
    always_ff @(posedge aclk) begin
        case (rd_state)
            RD_IDLE: if (axi4_if.arvalid) begin
                rd_id_q   <= axi4_if.arid;
                rd_addr_q <= axi4_if.araddr;
                rd_prot_q <= axi4_if.arprot;
                rd_word_q <= axi4_if.araddr[OFFSET_WID-1:2];
                if (axi4_if.arlen != 8'h0) begin
                    rd_data_q <= '0;
                    rd_resp_q <= 2'b10; // SLVERR for multi-beat
                end
            end
            RD_AXIL: if (axi4l_if.rvalid) begin
                rd_data_q <= axi4l_if.rdata;
                rd_resp_q <= axi4l_if.rresp;
            end
            default: ;
        endcase
    end

    // Combinational next-state and output
    always_comb begin
        rd_nxt_state = rd_state;
        case (rd_state)
            RD_IDLE: if (axi4_if.arvalid)  rd_nxt_state = (axi4_if.arlen != 8'h0) ? RD_RESP : RD_AXIL;
            RD_AXIL: if (axi4l_if.rvalid)  rd_nxt_state = RD_RESP;
            RD_RESP: if (axi4_if.rready)   rd_nxt_state = RD_IDLE;
            default:                        rd_nxt_state = RD_IDLE;
        endcase
    end

    // AXI4 read response outputs
    assign axi4_if.arready = (rd_state == RD_IDLE);
    assign axi4_if.rvalid  = (rd_state == RD_RESP);
    assign axi4_if.rid     = rd_id_q;
    assign axi4_if.rlast   = 1'b1;
    assign axi4_if.rresp   = rd_resp_q;
    assign axi4_if.ruser   = '0;

    // Place 32-bit read data on the correct word lane; zero-fill others.
    always_comb begin
        axi4_if.rdata = '0;
        axi4_if.rdata[rd_word_q*AXI4L_BYTE_WID +: AXI4L_BYTE_WID] = rd_data_q;
    end

    // AXI4-L read outputs
    assign axi4l_if.arvalid = (rd_state == RD_AXIL);
    assign axi4l_if.araddr  = AXI4L_ADDR_WID'(rd_addr_q & ~ADDR_WID'('h3));
    assign axi4l_if.arprot  = rd_prot_q;
    assign axi4l_if.rready  = (rd_state == RD_AXIL);

    // =========================================================================
    // AXI4-L clock/reset
    // =========================================================================
    assign axi4l_if.aclk    = aclk;
    assign axi4l_if.aresetn = aresetn;

endmodule : axi4l_from_axi4_adapter
