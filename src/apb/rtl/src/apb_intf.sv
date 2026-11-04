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

    wire mon_psel = psel;
    wire mon_penable = penable;

    clocking cb @(posedge pclk);
        output paddr, pprot, psel, penable, pwrite, pwdata, pstrb;
        input  pready, prdata, pslverr;
        input  mon_psel, mon_penable;
    endclocking

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
    assign apb_if.pclk = 1'b0;
    assign apb_if.presetn = 1'b0;
    assign apb_if.paddr = '0;
    assign apb_if.pprot = '0;
    assign apb_if.psel = 1'b0;
    assign apb_if.penable = 1'b0;
    assign apb_if.pwrite = 1'b0;
    assign apb_if.pwdata = '0;
    assign apb_if.pstrb = '0;

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
