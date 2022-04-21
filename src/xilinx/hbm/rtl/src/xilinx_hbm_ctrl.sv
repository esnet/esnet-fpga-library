// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================
module xilinx_hbm_ctrl
#(
    parameter int PSEUDO_CHANNELS = 16
)(
    // Clock/reset (memory interface)
    input logic           clk,
    input logic           srst,

    // AXI-L control interface
    axi4l_intf.peripheral axil_if,

    // AXI3 memory channel interfaces
    axi3_intf.controller  axi_if [PSEUDO_CHANNELS],
    
    // APB (management) interface
    input logic           apb_clk,
    apb_intf.controller   apb_if,

    // Status
    input logic           init_done,
    
    // DRAM status monitoring
    input logic           dram_status_cattrip,
    input logic [6:0]     dram_status_temp
);

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef struct packed {
        logic       init_done;
        logic [6:0] temp;
        logic       cattrip;
    } dram_status_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic         local_srst;
    logic [4:0]   apb_channel_sel__clk;
    logic [4:0]   apb_channel_sel__apb_clk;

    dram_status_t dram_status__apb_clk;
    dram_status_t dram_status__clk;

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf hbm_axil_if ();
    axi4l_intf hbm_axil_if__clk ();
    axi4l_intf hbm_channel_axil_if ();
    axi4l_intf hbm_channel_axil_if__apb_clk ();

    apb_intf hbm_channel_apb_if ();

    xilinx_hbm_reg_intf reg_if ();

    // -----------------------------
    // Terminate AXI-L control interface
    // -----------------------------
    // Top-level decoder
    xilinx_hbm_decoder i_xilinx_hbm_decoder (
        .axil_if                    ( axil_if ),
        .xilinx_hbm_axil_if         ( hbm_axil_if ),
        .xilinx_hbm_channel_axil_if ( hbm_channel_axil_if )
    );

    // CDC
    axi4l_intf_cdc i_axi4l_hbm_cdc (
        .axi4l_if_from_controller( hbm_axil_if ),
        .clk_to_peripheral       ( clk ),
        .axi4l_if_to_peripheral  ( hbm_axil_if__clk )
    );

    // HBM main control
    xilinx_hbm_reg_blk i_xilinx_hbm_reg_blk (
        .axil_if    ( hbm_axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    // Block-level reset control
    sync_reset #(
        .INPUT_ACTIVE_HIGH ( 1 )
    ) i_sync_reset (
        .rst_in   ( srst || reg_if.control.reset ),
        .clk_out  ( clk ),
        .srst_out ( local_srst )
    );

    // CDC (cross status signals from APB to clk clock domain)
    assign dram_status__apb_clk.init_done = init_done;
    assign dram_status__apb_clk.temp = dram_status_temp;
    assign dram_status__apb_clk.cattrip = dram_status_cattrip;

    sync_bus_sampled #(
        .DATA_T   ( dram_status_t )
    ) i_sync_bus_sampled__dram_status (
        .clk_in   ( apb_if.pclk ),
        .rst_in   ( !apb_if.presetn ),
        .data_in  ( dram_status__apb_clk ),
        .clk_out  ( clk ),
        .rst_out  ( srst ),
        .data_out ( dram_status__clk )
    );

    // Report status
    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.reset = local_srst;
    assign reg_if.status_nxt.init_done = dram_status__clk.init_done;

    assign reg_if.dram_status_nxt_v = 1'b1;
    assign reg_if.dram_status_nxt.cattrip = dram_status__clk.cattrip;
    assign reg_if.dram_status_nxt.temp = dram_status__clk.temp;

    // -----------------------------
    // Drive HBM channel config/status registers
    // -----------------------------
    // CDC
    axi4l_intf_cdc i_axi4l_hbm_channel_cdc (
        .axi4l_if_from_controller( hbm_channel_axil_if ),
        .clk_to_peripheral       ( apb_clk ),
        .axi4l_if_to_peripheral  ( hbm_channel_axil_if__apb_clk )
    );

    // Bridge to APB
    axi4l_apb_bridge i_axi4l_apb_bridge (
        .axi4l_if ( hbm_channel_axil_if__apb_clk ),
        .apb_if   ( hbm_channel_apb_if )
    );

    // Encode channel select address bits per Xilinx PG276 (v1.0):
    always_comb begin
        case (reg_if.cfg_apb_channel_sel.value)
            3'd0 : apb_channel_sel__clk = 5'b01000; // Memory Controller 0
            3'd1 : apb_channel_sel__clk = 5'b01100; // Memory Controller 1
            3'd2 : apb_channel_sel__clk = 5'b01001; // Memory Controller 2
            3'd3 : apb_channel_sel__clk = 5'b01101; // Memory Controller 3
            3'd4 : apb_channel_sel__clk = 5'b01010; // Memory Controller 4
            3'd5 : apb_channel_sel__clk = 5'b01110; // Memory Controller 5
            3'd6 : apb_channel_sel__clk = 5'b01011; // Memory Controller 6
            3'd7 : apb_channel_sel__clk = 5'b01111; // Memory Controller 7
        endcase
    end

    // Cross to APB clock domain
    sync_bus_sampled #(
        .DATA_T   ( dram_status_t )
    ) i_sync_bus_sampled__apb_channel_sel (
        .clk_in   ( clk ),
        .rst_in   ( srst ),
        .data_in  ( apb_channel_sel__clk ),
        .clk_out  ( apb_if.pclk ),
        .rst_out  ( !apb_if.presetn ),
        .data_out ( apb_channel_sel__apb_clk )
    );

    // Connect outgoing APB interface; augment PADDR with memory channel select
    assign apb_if.pclk    = hbm_channel_apb_if.pclk;
    assign apb_if.presetn = hbm_channel_apb_if.presetn;
    assign apb_if.paddr   = {apb_channel_sel__apb_clk, hbm_channel_apb_if.paddr[16:0]};
    assign apb_if.pprot   = hbm_channel_apb_if.pprot;
    assign apb_if.psel    = hbm_channel_apb_if.psel;
    assign apb_if.penable = hbm_channel_apb_if.penable;
    assign apb_if.pwrite  = hbm_channel_apb_if.pwrite;
    assign apb_if.pwdata  = hbm_channel_apb_if.pwdata;
    assign apb_if.pstrb   = hbm_channel_apb_if.pstrb;
    assign hbm_channel_apb_if.pready  = apb_if.pready;
    assign hbm_channel_apb_if.prdata  = apb_if.prdata;
    assign hbm_channel_apb_if.pslverr = apb_if.pslverr;

    // -----------------------------
    // Terminate unused AXI control interfaces
    // -----------------------------
    generate
        for (genvar g_if = 0; g_if < PSEUDO_CHANNELS; g_if++) begin : g__axi3_if_tieoff
            axi3_intf_controller_term i_axi3_intf_controller_term (
                .axi3_if ( axi_if [g_if] )
            );
        end : g__axi3_if_tieoff
    endgenerate

endmodule : xilinx_hbm_ctrl
