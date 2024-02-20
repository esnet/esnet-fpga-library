module mem_ram_sdp_async_wrapper #(
    parameter int ADDR_WID = 7,
    parameter int DATA_WID = 113,
    parameter bit RESET_FSM = 1
)(
    input  logic                 wr_clk,
    input  logic                 wr_srst,
    output logic                 wr_rdy,
    input  logic                 wr_en,
    input  logic                 wr_req,
    input  logic [ADDR_WID-1:0]  wr_addr,
    input  logic [DATA_WID-1:0]  wr_data,
    output logic                 wr_ack,

    input  logic                 rd_clk,
    input  logic                 rd_srst,
    output logic                 rd_rdy,
    input  logic                 rd_req,
    input  logic  [ADDR_WID-1:0] rd_addr,
    output logic  [DATA_WID-1:0] rd_data,
    output logic                 rd_ack
);
    // Parameters
    localparam mem_pkg::spec_t SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_WID,
        ASYNC: 1,
        RESET_FSM: RESET_FSM,
        OPT_MODE: mem_pkg::OPT_MODE_TIMING
    };

    // Interfaces
    mem_wr_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(wr_clk));
    mem_rd_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(rd_clk));

    // Write
    always_ff @(posedge wr_clk) begin
        mem_wr_if.rst <= wr_srst;
        mem_wr_if.en  <= wr_en;
        mem_wr_if.req <= wr_req;
        mem_wr_if.addr <= wr_addr;
        mem_wr_if.data <= wr_data;
        wr_rdy <= mem_wr_if.rdy;
        wr_ack <= mem_wr_if.ack;
    end

    // Read control
    always_ff @(posedge rd_clk) begin
        mem_rd_if.rst <= rd_srst;
        rd_rdy <= mem_rd_if.rdy;
        mem_rd_if.req <= rd_req;
        mem_rd_if.addr <= rd_addr;
        rd_data <= mem_rd_if.data;
        rd_ack <= mem_rd_if.ack;
    end

    mem_ram_sdp    #(
        .SPEC       ( SPEC )
    ) i_mem_ram_sdp (
        .*
    );

endmodule : mem_ram_sdp_async_wrapper
