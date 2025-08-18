module mem_ram_tdp_sync_wrapper #(
    parameter int ADDR_WID = 16,
    parameter int DATA_WID = 113,
    parameter bit RESET_FSM = 1
)(
    input  logic                 clk,

    input  logic                 srst_0,
    output logic                 rdy_0,
    input  logic                 req_0,
    input  logic                 wr_0,
    input  logic [ADDR_WID-1:0]  addr_0,
    input  logic [DATA_WID-1:0]  wr_data_0,
    output logic                 wr_ack_0,
    output logic [DATA_WID-1:0]  rd_data_0,
    output logic                 rd_ack_0,

    input  logic                 srst_1,
    output logic                 rdy_1,
    input  logic                 req_1,
    input  logic                 wr_1,
    input  logic [ADDR_WID-1:0]  addr_1,
    input  logic [DATA_WID-1:0]  wr_data_1,
    output logic                 wr_ack_1,
    output logic [DATA_WID-1:0]  rd_data_1,
    output logic                 rd_ack_1
);
    // Parameters
    localparam mem_pkg::spec_t SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_WID,
        ASYNC: 0,
        RESET_FSM: RESET_FSM,
        OPT_MODE: mem_pkg::OPT_MODE_TIMING
    };

    // Interfaces
    mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_if_0 (.clk(clk));
    mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_if_1 (.clk(clk));

    // Signals
    logic                mem_if_0__rst;
    logic                mem_if_0__req;
    logic                mem_if_0__wr;
    logic [ADDR_WID-1:0] mem_if_0__addr;
    logic [DATA_WID-1:0] mem_if_0__wr_data;

    logic  mem_if_1__rst;
    logic  mem_if_1__req;
    logic  mem_if_1__wr;
    logic [ADDR_WID-1:0] mem_if_1__addr;
    logic [DATA_WID-1:0] mem_if_1__wr_data;

    // Port 0
    always_ff @(posedge clk) begin
        mem_if_0__rst <= srst_0;
        mem_if_0__req <= req_0;
        mem_if_0__wr <= wr_0;
        mem_if_0__addr <= addr_0;
        mem_if_0__wr_data <= wr_data_0;
        rdy_0 <= mem_if_0.rdy;
        wr_ack_0 <= mem_if_0.wr_ack;
        rd_data_0 <= mem_if_0.rd_data;
        rd_ack_0 <= mem_if_0.rd_ack;
    end

    assign mem_if_0.rst     = mem_if_0__rst;
    assign mem_if_0.req     = mem_if_0__req;
    assign mem_if_0.wr      = mem_if_0__wr;
    assign mem_if_0.addr    = mem_if_0__addr;
    assign mem_if_0.wr_data = mem_if_0__wr_data;

    // Port 1
    always_ff @(posedge clk) begin
        mem_if_1__rst <= srst_1;
        mem_if_1__req <= req_1;
        mem_if_1__wr <= wr_1;
        mem_if_1__addr <= addr_1;
        mem_if_1__wr_data <= wr_data_1;
        rdy_1 <= mem_if_1.rdy;
        wr_ack_1 <= mem_if_1.wr_ack;
        rd_data_1 <= mem_if_1.rd_data;
        rd_ack_1 <= mem_if_1.rd_ack;
    end

    assign mem_if_1.rst     = mem_if_1__rst;
    assign mem_if_1.req     = mem_if_1__req;
    assign mem_if_1.wr      = mem_if_1__wr;
    assign mem_if_1.addr    = mem_if_1__addr;
    assign mem_if_1.wr_data = mem_if_1__wr_data;

    // Memory instantiation
    mem_ram_tdp    #(
        .SPEC       ( SPEC )
    ) i_mem_ram_tdp (
        .*
    );

endmodule : mem_ram_tdp_sync_wrapper
