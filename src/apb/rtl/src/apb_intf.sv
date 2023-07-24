interface apb_intf
    import apb_pkg::*;
#(
    parameter int  DATA_BYTE_WID = 4,
    parameter int  ADDR_WID = 32
);
    // Parameters
    typedef logic [DATA_BYTE_WID-1:0][7:0] data_t;

    // Signals
    // -- Clock/reset
    logic                      pclk;
    logic                      presetn;
    // -- Write address
    logic [ADDR_WID-1:0]       paddr;
    pprot_t                    pprot;
    logic                      psel;
    logic                      penable;
    logic                      pwrite;
    data_t                     pwdata;
    logic [DATA_BYTE_WID-1:0]  pstrb;
    logic                      pready;
    data_t                     prdata;
    logic                      pslverr;

    // Modports
    modport controller (
        output pclk,
        output presetn,
        output paddr,
        output pprot,
        output psel,
        output penable,
        output pwrite,
        output pwdata,
        output pstrb,
        input  pready,
        input  prdata,
        input  pslverr
    );
       
    modport peripheral (
        input  pclk,
        input  presetn,
        input  paddr,
        input  pprot,
        input  psel,
        input  penable,
        input  pwrite,
        input  pwdata,
        input  pstrb,
        output pready,
        output prdata,
        output pslverr
    );

    clocking cb @(posedge pclk);
        default input #1step output #1step;
        output paddr, pprot, psel, penable, pwrite, pwdata, pstrb;
        input  pready, prdata, pslverr;
    endclocking

    task idle_controller();
        cb.paddr   <=   '0;
        cb.pprot   <=   '0;
        cb.psel    <= 1'b0;
        cb.penable <= 1'b0;
        cb.pwrite  <= 1'b0;
        cb.pwdata  <=   '0;
        cb.pstrb   <=   '0;
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task _write(
            input  bit [ADDR_WID-1:0]      addr,
            input  data_t                  data,
            input  bit [DATA_BYTE_WID-1:0] strb,
            output bit                     error          
        );
        cb.psel <= 1'b1;
        cb.paddr <= addr;
        cb.pwdata <= data;
        cb.pwrite <= 1'b1;
        @(cb);
        cb.penable <= 1'b1;
        wait (cb.pready);
        cb.psel <= 1'b0;
        cb.penable <= 1'b0;
        error = cb.pslverr;
    endtask

    task _read(
            input  bit [ADDR_WID-1:0] addr,
            output data_t             data,
            output bit                error
        );
        cb.psel <= 1'b1;
        cb.paddr <= addr;
        cb.pwrite <= 1'b0;
        @(cb);
        cb.penable <= 1'b1;
        wait(cb.pready);
        cb.psel <= 1'b0;
        cb.penable <= 1'b0;
        error = cb.pslverr;
        data = cb.prdata;
    endtask

    task read(
            input  bit [ADDR_WID-1:0] addr,
            output data_t             data,
            output bit error,
            output bit timeout,
            input  int RD_TIMEOUT = 0
        );
        error = 1'b0;
        timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        _read(addr, data, error);
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
        if (timeout) idle_controller();
    endtask

    task write(
            input  bit [ADDR_WID-1:0]      addr,
            input  data_t                  data,
            input  bit [DATA_BYTE_WID-1:0] strb,
            output bit error,
            output bit timeout,
            input  int WR_TIMEOUT = 0
        );
        error = 1'b0;
        timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        _write(addr, data, strb, error);
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
        if (timeout) idle_controller();
    endtask

endinterface : apb_intf

// APB (back-to-back) connector helper module
module apb_intf_connector (
    apb_intf.peripheral apb_if_from_controller,
    apb_intf.controller apb_if_to_peripheral
);
    assign apb_if_to_peripheral.pclk = apb_if_from_controller.pclk;
    assign apb_if_to_peripheral.presetn = apb_if_from_controller.presetn;
    assign apb_if_to_peripheral.paddr = apb_if_from_controller.paddr;
    assign apb_if_to_peripheral.pprot = apb_if_from_controller.pprot;
    assign apb_if_to_peripheral.psel = apb_if_from_controller.psel;
    assign apb_if_to_peripheral.penable = apb_if_from_controller.penable;
    assign apb_if_to_peripheral.pwrite = apb_if_from_controller.pwrite;
    assign apb_if_to_peripheral.pwdata = apb_if_from_controller.pwdata;
    assign apb_if_to_peripheral.pstrb = apb_if_from_controller.pstrb;
    assign apb_if_from_controller.pready = apb_if_to_peripheral.pready;
    assign apb_if_from_controller.prdata = apb_if_to_peripheral.prdata;
    assign apb_if_from_controller.pslverr = apb_if_to_peripheral.pslverr;

endmodule : apb_intf_connector


// APB peripheral termination helper module
module apb_intf_peripheral_term
(
    apb_intf.peripheral apb_if
);
    // Tie off peripheral outputs
    assign apb_if.pready = 1'b0;
    assign apb_if.prdata = '0;
    assign apb_if.pslverr = 1'b1;

endmodule : apb_intf_peripheral_term


// APB controller termination helper module
module apb_intf_controller_term (
    apb_intf.controller apb_if
);
    import apb_pkg::*;

    // Tie off controller outputs
    assign apb_if_to_peripheral.pclk = 1'b0;
    assign apb_if_to_peripheral.presetn = 1'b0;
    assign apb_if_to_peripheral.paddr = '0;
    assign apb_if_to_peripheral.pprot = '0;
    assign apb_if_to_peripheral.psel = 1'b0;
    assign apb_if_to_peripheral.penable = 1'b0;
    assign apb_if_to_peripheral.pwrite = 1'b0;
    assign apb_if_to_peripheral.pwdata = '0;
    assign apb_if_to_peripheral.pstrb = '0;

endmodule : apb_intf_controller_term


// Collect flattened APB signals (from controller) into interface (to peripheral)
module apb_intf_from_signals
#(
    parameter int DATA_BYTE_WID = 4,
    parameter int ADDR_WID = 32
) (
    // Signals (from controller)
    input  logic                          pclk,
    input  logic                          presetn,
    input  logic [ADDR_WID-1:0]           paddr,
    input  logic [2:0]                    pprot,
    input  logic                          psel,
    input  logic                          penable,
    input  logic                          pwrite,
    input  logic [DATA_BYTE_WID-1:0][7:0] pwdata,
    input  logic [DATA_BYTE_WID-1:0]      pstrb,
    output logic                          pready,
    output logic [DATA_BYTE_WID-1:0][7:0] prdata,
    output logic                          pslverr,

    // Interface (to peripheral)
    apb_intf.controller                   apb_if
);
    assign apb_if.pclk = pclk;
    assign apb_if.presetn = presetn;
    assign apb_if.paddr = paddr;
    assign apb_if.pprot = pprot;
    assign apb_if.psel = psel;
    assign apb_if.penable = penable;
    assign apb_if.pwrite = pwrite;
    assign apb_if.pwdata = pwdata;
    assign apb_if.pstrb = pstrb;
    assign pready = apb_if.pready;
    assign prdata = apb_if.prdata;
    assign pslverr = apb_if.pslverr;

endmodule : apb_intf_from_signals


// Break interface (from controller) into flattened APB signals (to peripheral)
module apb_intf_to_signals
#(
    parameter int DATA_BYTE_WID = 4,
    parameter int ADDR_WID = 32
) (
    // Interface (from controller)
    apb_intf.peripheral  apb_if,
 
    // Signals (to peripheral)
    output logic                          pclk,
    output logic                          presetn,
    output logic [ADDR_WID-1:0]           paddr,
    output logic [2:0]                    pprot,
    output logic                          psel,
    output logic                          penable,
    output logic                          pwrite,
    output logic [DATA_BYTE_WID-1:0][7:0] pwdata,
    output logic [DATA_BYTE_WID-1:0]      pstrb,
    input  logic                          pready,
    input  logic [DATA_BYTE_WID-1:0][7:0] prdata,
    input  logic                          pslverr
);
    assign pclk = apb_if.pclk;
    assign presetn = apb_if.presetn;
    assign paddr = apb_if.paddr;
    assign pprot = apb_if.pprot;
    assign psel = apb_if.psel;
    assign penable = apb_if.penable;
    assign pwrite = apb_if.pwrite;
    assign pwdata = apb_if.pwdata;
    assign pstrb = apb_if.pstrb;
    assign apb_if.pready = pready;
    assign apb_if.prdata = prdata;
    assign apb_if.pslverr = pslverr;

endmodule : apb_intf_to_signals
