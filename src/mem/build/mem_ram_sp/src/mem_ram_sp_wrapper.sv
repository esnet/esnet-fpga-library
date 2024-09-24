module mem_ram_sp_wrapper #(
    parameter int ADDR_WID = 16,
    parameter int DATA_WID = 113,
    parameter bit RESET_FSM = 1
)(
    input  logic                 clk,
    input  logic                 srst,
    output logic                 rdy,
    input  logic                 req,
    input  logic                 wr,
    input  logic [ADDR_WID-1:0]  addr,
    input  logic [DATA_WID-1:0]  wr_data,
    output logic                 wr_ack,
    output logic [DATA_WID-1:0]  rd_data,
    output logic                 rd_ack
);
    // Parameters
    localparam mem_pkg::spec_t SPEC = '{
        ADDR_WID: ADDR_WID,
        DATA_WID: DATA_WID,
        ASYNC: 0,
        RESET_FSM: RESET_FSM,
        OPT_MODE: mem_pkg::OPT_MODE_TIMING
    };

    localparam type ADDR_T = logic[ADDR_WID-1:0];
    localparam type DATA_T = logic[DATA_WID-1:0];

    // Interfaces
    mem_intf #(.ADDR_T(ADDR_T), .DATA_T(DATA_T)) mem_if (.clk(clk));

    // Signals
    logic  mem_if__rst;
    logic  mem_if__req;
    logic  mem_if__wr;
    ADDR_T mem_if__addr;
    DATA_T mem_if__wr_data;

    always_ff @(posedge clk) begin
        mem_if__rst <= srst;
        mem_if__req <= req;
        mem_if__wr <= wr;
        mem_if__addr <= addr;
        mem_if__wr_data <= wr_data;
        rdy <= mem_if.rdy;
        wr_ack <= mem_if.wr_ack;
        rd_data <= mem_if.rd_data;
        rd_ack <= mem_if.rd_ack;
    end

    assign mem_if.rst     = mem_if__rst;
    assign mem_if.req     = mem_if__req;
    assign mem_if.wr      = mem_if__wr;
    assign mem_if.addr    = mem_if__addr;
    assign mem_if.wr_data = mem_if__wr_data;

    // Memory instantiation
    mem_ram_sp    #(
        .SPEC       ( SPEC )
    ) i_mem_ram_sp (
        .*
    );

endmodule : mem_ram_sp_wrapper
