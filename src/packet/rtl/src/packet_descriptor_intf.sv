interface packet_descriptor_intf #(
    parameter int ADDR_WID = 1,
    parameter int META_WID = 1,
    parameter int MAX_PKT_SIZE = 16383
) (
    input logic clk
);
    // Parameters
    localparam int SIZE_WID = $clog2(MAX_PKT_SIZE+1);

    // Signals
    logic                                        vld;
    logic                                        rdy;
    logic [ADDR_WID-1:0]                         addr;
    logic [SIZE_WID-1:0]                         size;
    logic                                        err;
    logic [META_WID-1:0]                         meta;
    logic [packet_pkg::CKSUM_FIELD_WID-1:0]      cksum;  // 0 = not calculated

    // Modports
    modport tx(
        input  clk,
        output vld,
        input  rdy,
        output addr,
        output size,
        output err,
        output meta,
        output cksum
    );

    modport rx(
        input  clk,
        input  vld,
        output rdy,
        input  addr,
        input  size,
        input  err,
        input  meta,
        input  cksum
    );

`ifndef SYNTHESIS
    // Verification clocking blocks
    // Separate nets let testbench agents sample driven signals.
    // Clocking-block input aliases are not supported by xsim.
    logic mon_tx_vld, mon_rx_rdy;
    assign mon_tx_vld = vld;
    assign mon_rx_rdy = rdy;

    clocking cb_tx @(posedge clk);
        output vld, addr, size, err, meta, cksum;
        input rdy, mon_tx_vld;
    endclocking

    clocking cb_rx @(posedge clk);
        input vld, addr, size, err, meta, cksum, mon_rx_rdy;
        output rdy;
    endclocking
`endif


endinterface : packet_descriptor_intf

// Packet descriptor interface (back-to-back) connector helper module
module packet_descriptor_intf_connector (
    packet_descriptor_intf.rx from_tx,
    packet_descriptor_intf.tx to_rx
);
    // Parameter check
    initial begin
        std_pkg::param_check(to_rx.ADDR_WID, from_tx.ADDR_WID, "to_rx.ADDR_WID");
        std_pkg::param_check(to_rx.META_WID, from_tx.META_WID, "to_rx.META_WID");
        std_pkg::param_check_gt(to_rx.MAX_PKT_SIZE, from_tx.MAX_PKT_SIZE, "to_rx.MAX_PKT_SIZE");
    end

    // Connect signals (tx -> rx)
    assign to_rx.vld   = from_tx.vld;
    assign to_rx.addr  = from_tx.addr;
    assign to_rx.size  = from_tx.size;
    assign to_rx.err   = from_tx.err;
    assign to_rx.meta  = from_tx.meta;
    assign to_rx.cksum = from_tx.cksum;

    // Connect signals (rx -> tx)
    assign from_tx.rdy = to_rx.rdy;

endmodule : packet_descriptor_intf_connector

// Packet descriptor delay pipe
module packet_descriptor_intf_delay #(
    parameter int STAGES = 1
) (
    packet_descriptor_intf.rx from_tx,
    packet_descriptor_intf.tx to_rx
);
    // Parameters
    localparam int ADDR_WID     = from_tx.ADDR_WID;
    localparam int META_WID     = from_tx.META_WID;
    localparam int MAX_PKT_SIZE = from_tx.MAX_PKT_SIZE;
    localparam int SIZE_WID     = $clog2(MAX_PKT_SIZE+1);

    // Parameter check
    initial begin
        std_pkg::param_check(to_rx.ADDR_WID, ADDR_WID, "to_rx.ADDR_WID");
        std_pkg::param_check(to_rx.META_WID, META_WID, "to_rx.META_WID");
        std_pkg::param_check_gt(to_rx.MAX_PKT_SIZE, MAX_PKT_SIZE, "to_rx.MAX_PKT_SIZE");
        std_pkg::param_check_gt(STAGES, 1, "to_rx.MAX_PKT_SIZE");
    end

    localparam int CKSUM_WID = packet_pkg::CKSUM_FIELD_WID;

    typedef struct packed {
        logic[ADDR_WID-1:0]  addr;
        logic[SIZE_WID-1:0]  size;
        logic[META_WID-1:0]  meta;
        logic                err;
        logic[CKSUM_WID-1:0] cksum;
    } desc_t;

    logic  desc_vld  [STAGES];
    desc_t desc_pipe [STAGES];

    // Connect signals (tx -> rx) through delay pipeline
    initial desc_vld = '{STAGES{1'b0}};
    always @(posedge from_tx.clk) begin
        if (to_rx.rdy) begin
            for (int i = 1; i < STAGES; i++) desc_vld[i] <= desc_vld[i-1];
            desc_vld[0] <= from_tx.vld;
        end
    end

    always_ff @(posedge from_tx.clk) begin
        if (to_rx.rdy) begin
            for (int i = 1; i < STAGES; i++) desc_pipe[i] <= desc_pipe[i-1];
            desc_pipe[0].addr  <= from_tx.addr;
            desc_pipe[0].size  <= from_tx.size;
            desc_pipe[0].meta  <= from_tx.meta;
            desc_pipe[0].err   <= from_tx.err;
            desc_pipe[0].cksum <= from_tx.cksum;
        end
    end

    assign to_rx.vld   = desc_vld[STAGES-1];
    assign to_rx.addr  = desc_pipe[STAGES-1].addr;
    assign to_rx.size  = desc_pipe[STAGES-1].size;
    assign to_rx.err   = desc_pipe[STAGES-1].err;
    assign to_rx.meta  = desc_pipe[STAGES-1].meta;
    assign to_rx.cksum = desc_pipe[STAGES-1].cksum;

    // Connect signals (rx -> tx)
    assign from_tx.rdy = to_rx.rdy;

endmodule : packet_descriptor_intf_delay


// Packet descriptor interface connector with meta rewrite
module packet_descriptor_intf_set_meta #(
    parameter int META_WID = 1
) (
    packet_descriptor_intf.rx  from_tx,
    packet_descriptor_intf.tx  to_rx,
    input logic [META_WID-1:0] meta
);
    // Parameter check
    initial begin
        std_pkg::param_check(to_rx.ADDR_WID, from_tx.ADDR_WID, "to_rx.ADDR_WID");
        std_pkg::param_check(to_rx.META_WID, META_WID, "to_rx.META_WID");
        std_pkg::param_check_gt(to_rx.MAX_PKT_SIZE, from_tx.MAX_PKT_SIZE, "to_rx.MAX_PKT_SIZE");
    end

    // Connect signals (tx -> rx)
    assign to_rx.vld   = from_tx.vld;
    assign to_rx.addr  = from_tx.addr;
    assign to_rx.size  = from_tx.size;
    assign to_rx.err   = from_tx.err;
    assign to_rx.meta  = meta;
    assign to_rx.cksum = from_tx.cksum;

    // Connect signals (rx -> tx)
    assign from_tx.rdy = to_rx.rdy;

endmodule : packet_descriptor_intf_set_meta