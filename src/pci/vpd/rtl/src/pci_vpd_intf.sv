interface pci_vpd_intf (
    input logic clk
);

    import pci_vpd_pkg::*;

    // Signals
    logic                    req;
    logic                    wr_rd_n;
    logic [VPD_ADDR_WID-1:0] addr;
    logic [7:0]              wr_data;
    logic [7:0]              rd_data;
    logic                    rd_vld;

    // Modports
    modport controller (
        input  clk,
        output req,
        output wr_rd_n,
        output addr,
        output wr_data,
        input  rd_data,
        input  rd_vld
    );
       
    modport peripheral (
        input  clk,
        input  req,
        input  wr_rd_n,
        input  addr,
        input  wr_data,
        output rd_data,
        output rd_vld
    );

    clocking cb @(posedge clk);
        output req, wr_rd_n, addr, wr_data;
        input  rd_data, rd_vld;
    endclocking

endinterface : pci_vpd_intf
