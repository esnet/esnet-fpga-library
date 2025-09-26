module packet_fifo
#(
    parameter bit  ASYNC = 0,
    parameter bit  CUT_THROUGH = 0,
    parameter int  IGNORE_RDY_IN = 0,
    parameter int  IGNORE_RDY_OUT = 0,
    parameter bit  DROP_ERRORED = 1,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    parameter int  DEPTH = 512,
    parameter int  MAX_DESCRIPTORS = 32,
    // Simulation-only
    parameter bit  SIM__RAM_MODEL = 0
 ) (
    packet_intf.rx  packet_in_if,
    packet_intf.tx  packet_out_if
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int  DATA_BYTE_WID = packet_in_if.DATA_BYTE_WID;
    localparam int  DATA_WID = DATA_BYTE_WID * 8;
    localparam int  ADDR_WID = $clog2(DEPTH);

    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_WID,
        ASYNC: ASYNC,
        RESET_FSM: 0,
        OPT_MODE: mem_pkg::OPT_MODE_TIMING
    };

    localparam MAX_RD_LATENCY = mem_pkg::get_rd_latency(MEM_SPEC);

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check(packet_out_if.DATA_BYTE_WID, packet_in_if.DATA_BYTE_WID, "to_rx.DATA_BYTE_WID");
        std_pkg::param_check(packet_out_if.META_WID, packet_in_if.META_WID, "to_rx.META_WID");
    end

    // -----------------------------
    // Interfaces
    // -----------------------------
    mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(packet_in_if.clk));
    mem_rd_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(packet_out_if.clk));

    packet_event_intf event_in_if  (.clk(packet_in_if.clk));
    packet_event_intf event_out_if (.clk(packet_out_if.clk));

    // -----------------------------
    // FIFO logic
    // -----------------------------
    packet_fifo_core    #(
        .ASYNC           ( ASYNC ),
        .CUT_THROUGH     ( CUT_THROUGH ),
        .IGNORE_RDY_IN   ( IGNORE_RDY_IN ),
        .IGNORE_RDY_OUT  ( IGNORE_RDY_OUT ),
        .DROP_ERRORED    ( DROP_ERRORED ),
        .MIN_PKT_SIZE    ( MIN_PKT_SIZE ),
        .MAX_PKT_SIZE    ( MAX_PKT_SIZE ),
        .DEPTH           ( DEPTH ),
        .MAX_DESCRIPTORS ( MAX_DESCRIPTORS ),
        .MAX_RD_LATENCY  ( MAX_RD_LATENCY )
    ) i_packet_fifo_core (
        .mem_init_done   ( 1'b1 ),
        .*
    );

    // -----------------------------
    // Memory instantiation
    // -----------------------------
    mem_ram_sdp #(
        .SPEC ( MEM_SPEC ),
        .SIM__RAM_MODEL ( SIM__RAM_MODEL )
    ) i_mem_ram_sdp (
        .*
    );

endmodule : packet_fifo
