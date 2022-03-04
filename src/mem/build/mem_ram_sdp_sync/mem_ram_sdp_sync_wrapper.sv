module mem_ram_sdp_sync_wrapper #(
    parameter int ADDR_WID = 16,
    parameter int DATA_WID = 16,
    parameter bit RESET_FSM = 1
)(
    input  logic                 clk,
    input  logic                 srst,

    output logic                 init_done,

    input  logic                 wr_rst,
    output logic                 wr_rdy,
    input  logic                 wr_en,
    input  logic                 wr_req,
    input  logic [ADDR_WID-1:0]  wr_addr,
    input  logic [DATA_WID-1:0]  wr_data,
    output logic                 wr_ack,

    input  logic                 rd_rst,
    output logic                 rd_rdy,
    input  logic                 rd_en,
    input  logic                 rd_req,
    input  logic  [ADDR_WID-1:0] rd_addr,
    output logic  [DATA_WID-1:0] rd_data,
    output logic                 rd_ack
);

    // Interfaces
    mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(clk));
    mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(clk));

    // Wrapper logic
    always_ff @(posedge clk) begin
        if (srst) begin
            // Write control
            mem_wr_if.rst <= 1'b0;
            mem_wr_if.en <= 1'b0;
            mem_wr_if.req <= 1'b0;
            wr_rdy <= 1'b0;
            wr_ack <= 1'b0;
            // Read control
            mem_rd_if.rst <= 1'b0;
            mem_rd_if.en <= 1'b0;
            mem_rd_if.req <= 1'b0;
            rd_rdy <= 1'b0;
            rd_ack <= 1'b0;
        end else begin
            // Write control
            mem_wr_if.rst <= wr_rst;
            mem_wr_if.en  <= wr_en;
            mem_wr_if.req <= wr_req;
            wr_rdy <= mem_wr_if.rdy;
            wr_ack <= mem_wr_if.ack;
            // Read control
            mem_rd_if.rst <= rd_rst;
            mem_rd_if.en  <= rd_en;
            mem_rd_if.req <= rd_req;
            rd_rdy <= mem_rd_if.rdy;
            rd_ack <= mem_rd_if.ack;
        end
    end

    always_ff @(posedge clk) begin
        // Write address/data
        mem_wr_if.addr <= wr_addr;
        mem_wr_if.data <= wr_data;
        // Read address/data
        mem_rd_if.addr <= rd_addr;
        rd_data <= mem_rd_if.data;
    end

    mem_ram_sdp_sync #(
        .ADDR_WID ( ADDR_WID ),
        .DATA_WID ( DATA_WID ),
        .RESET_FSM ( RESET_FSM )
    ) i_mem_ram_sdp_sync (
        .clk       ( clk ),
        .srst      ( srst ),
        .init_done ( init_done ),
        .mem_wr_if ( mem_wr_if ),
        .mem_rd_if ( mem_rd_if )
    );

endmodule : mem_ram_sdp_sync_wrapper
