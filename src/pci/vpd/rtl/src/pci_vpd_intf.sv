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

    task idle();
        cb.req <= 1'b0;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task _write(
            input  bit [VPD_ADDR_WID-1:0]  addr,
            input  bit [7:0]               data
        );
        cb.req <= 1'b1;
        cb.wr_rd_n <= 1'b1;
        cb.addr <= addr;
        cb.wr_data <= data;
        @(cb);
        cb.req <= 1'b0;
    endtask

    task _read(
            input  bit [VPD_ADDR_WID-1:0] addr,
            output bit [7:0]              data
        );
        cb.req <= 1'b1;
        cb.wr_rd_n <= 1'b0;
        cb.addr <= addr;
        @(cb);
        cb.req <= 1'b0;
        wait(cb.rd_vld);
        data = cb.rd_data;
    endtask

    task read(
            input  bit [VPD_ADDR_WID-1:0] addr,
            output bit [7:0]              data,
            output bit timeout,
            input  int RD_TIMEOUT = 0
        );
        timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        _read(addr, data);
                    end
                    begin
                        if (RD_TIMEOUT > 0) begin
                            _wait(RD_TIMEOUT);
                            timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        if (timeout) idle();
    endtask

    task write(
            input  bit [VPD_ADDR_WID-1:0] addr,
            input  bit [7:0]              data,
            output bit timeout,
            input  int WR_TIMEOUT = 0
        );
        timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        _write(addr, data);
                    end
                    begin
                        if (WR_TIMEOUT > 0) begin
                            _wait(WR_TIMEOUT);
                            timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        if (timeout) idle();
    endtask

endinterface : pci_vpd_intf