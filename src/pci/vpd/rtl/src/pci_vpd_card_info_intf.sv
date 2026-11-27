// Read-only card-info cache, with one outstanding byte request at a time.
interface pci_vpd_card_info_intf (
    input logic clk
);
    logic       srst;
    logic       vld;
    logic       error;
    logic [8:0] len;
    logic       rd;
    logic [8:0] rd_addr;
    logic [7:0] rd_data;
    logic       rd_vld;

    modport provider (
        input  clk,
        output srst,
        output vld,
        output error,
        output len,
        input  rd,
        input  rd_addr,
        output rd_data,
        output rd_vld
    );

    modport consumer (
        input  clk,
        input  srst,
        input  vld,
        input  error,
        input  len,
        output rd,
        output rd_addr,
        input  rd_data,
        input  rd_vld
    );

`ifndef SYNTHESIS
    clocking cb_provider @(posedge clk);
        input  rd, rd_addr;
        output srst, vld, error, len, rd_data, rd_vld;
    endclocking

    clocking cb_consumer @(posedge clk);
        output rd, rd_addr;
        input  srst, vld, error, len, rd_data, rd_vld;
    endclocking
`endif
endinterface : pci_vpd_card_info_intf
