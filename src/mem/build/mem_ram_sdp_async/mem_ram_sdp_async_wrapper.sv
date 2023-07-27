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
    input  logic                 rd_en,
    input  logic                 rd_req,
    input  logic  [ADDR_WID-1:0] rd_addr,
    output logic  [DATA_WID-1:0] rd_data,
    output logic                 rd_ack,

    output logic                 init_done
);

    // Interfaces
    mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(wr_clk));
    mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(rd_clk));

    // Write control
    always_ff @(posedge wr_clk) begin
        if (wr_srst) begin
            mem_wr_if.rst <= 1'b0;
            mem_wr_if.en <= 1'b0;
            mem_wr_if.req <= 1'b0;
            wr_rdy <= 1'b0;
            wr_ack <= 1'b0;
        end else begin
            mem_wr_if.rst <= wr_srst;
            mem_wr_if.en  <= wr_en;
            mem_wr_if.req <= wr_req;
            wr_rdy <= mem_wr_if.rdy;
            wr_ack <= mem_wr_if.ack;
        end
    end

    // Read control
    always_ff @(posedge rd_clk) begin
        if (rd_srst) begin
            mem_rd_if.rst <= 1'b0;
            mem_rd_if.en <= 1'b0;
            mem_rd_if.req <= 1'b0;
            rd_rdy <= 1'b0;
            rd_ack <= 1'b0;
        end else begin
            mem_rd_if.rst <= rd_srst;
            mem_rd_if.req <= rd_req;
            mem_rd_if.en  <= rd_en;
            rd_rdy <= mem_rd_if.rdy;
            rd_ack <= mem_rd_if.ack;
        end

    end

    // Write address/data
    always_ff @(posedge wr_clk) begin
        // Write address/data
        mem_wr_if.addr <= wr_addr;
        mem_wr_if.data <= wr_data;
    end

    // Read address/data
    always_ff @(posedge rd_clk) begin
        // Read address/data
        mem_rd_if.addr <= rd_addr;
        rd_data <= mem_rd_if.data;
    end

    mem_ram_sdp_async #(
        .ADDR_WID ( ADDR_WID ),
        .DATA_WID ( DATA_WID ),
        .RESET_FSM ( RESET_FSM )
    ) i_mem_ram_sdp_async (
        .wr_clk    ( wr_clk ),
        .wr_srst   ( wr_srst ),
        .rd_clk    ( rd_clk ),
        .rd_srst   ( rd_srst ),
        .init_done ( init_done ),
        .mem_wr_if ( mem_wr_if ),
        .mem_rd_if ( mem_rd_if )
    );

endmodule : mem_ram_sdp_async_wrapper
