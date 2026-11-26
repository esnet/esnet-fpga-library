// Initialization control/status in the free-running VPD clock domain.
interface pci_vpd_ctrl_intf;
    logic        clk;
    logic        srst;
    logic        init_done_mask;
    logic        init_done;
    logic        init_error;
    logic        init_timeout;
    logic        init_early_read;
    logic [13:0] init_time_ms;

    modport controller (
        output clk,
        output srst,
        output init_done_mask,
        input  init_done,
        input  init_error,
        input  init_timeout,
        input  init_early_read,
        input  init_time_ms
    );

    modport peripheral (
        input  clk,
        input  srst,
        input  init_done_mask,
        output init_done,
        output init_error,
        output init_timeout,
        output init_early_read,
        output init_time_ms
    );

`ifndef SYNTHESIS
    clocking cb @(posedge clk);
        output srst, init_done_mask;
        input  init_done, init_error, init_timeout, init_early_read, init_time_ms;
    endclocking
`endif
endinterface : pci_vpd_ctrl_intf
