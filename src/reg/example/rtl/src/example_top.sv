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

// -----------------------------------------------------------------------------
// example_top
//
// This module represents a fully-functional example of a 'top-level' design
// component that contains a relatively complex control plane. Specifically, it
// contains a decoder that distributes an 'upstream' AXI-L control interface to 
// multiple AXI-L peripheral components implementing separate blocks of
// registers. The decoder performs address decoding and translation, and data
// muxing/muxing to/from the peripheral components.
//
// The decoder and register blocks are described in the `example_decoder.yaml`
// and `example_reg_blk.yaml` specifications, at example/reg/.
//
// From this yaml description, the regio tool is used to autogenerate a
// a SystemVerilog decoder component. The regio tool is automatically invoked by
// the Make infrastructure, resulting in the following source files being
// generated (at example/reg/src/):
//
//    * example_decoder_pkg.sv:
//
//         Definitions package describing parameters, types and structs
//         describing register offsets, register formats, field packing, etc.
//
//    * example_decoder.sv:
//
//         Module description describing register block. Contains all of the
//         registers as defined in the example.yaml specification, as well
//         as local address decoding and data mux/demux functions.
//
// The example_top module describes how the autogenerated decoder gets
// instantiated and connected to client register blocks.
// -----------------------------------------------------------------------------

module example_top
#(
) (
    // Datapath clock/reset
    input logic clk,

    // AXI4-Lite control (upstream) interface
    axi4l_intf.peripheral      axil_if
);
    // -------------------------------------------------------------------------
    // Local interface declarations
    //
    // These AXI-L interfaces are used to interconnect the decoder and the
    // downstream peripheral components.
    //
    // Note: the decoder assumes that the upstream and downstream AXI-L
    // interfaces are synchronous so the upstream aclk is used as the aclk for
    // the downstream interfaces.
    // -------------------------------------------------------------------------
    axi4l_intf axil_if_component_0 ();
    axi4l_intf axil_if_component_1 ();
    axi4l_intf axil_if_component_2 ();

    // -------------------------------------------------------------------------
    // Decoder
    //
    // Top-level decoder is instantiated here. The decoder is described in the
    // example/reg/example_decoder.yaml specification and autogenerated by the
    // regio tool.
    //
    // The decoder takes an AXI-L control (upstream) interface and distributes
    // it to three (downstream) peripherals. The decoder performs address decode
    // and translation according to the address assignments in the yaml file;
    // data demuxing/muxing to/from the peripherals is also performed.
    // -------------------------------------------------------------------------
    example_decoder i_example_decoder (
        .axil_if                      ( axil_if ),
        .example_component_0_axil_if  ( axil_if_component_0 ),
        .example_component_1_axil_if  ( axil_if_component_1 ),
        .example_component_2_axil_if  ( axil_if_component_2 )
    );

    // -------------------------------------------------------------------------
    // Peripheral components
    //
    // Three instances of `example_component` are instantiated here to illustrate
    // the interconnection of the decoder with multiple downstream peripheral
    // devices.
    //
    // Components 0 and 1 operate synchronously to the `axil_aclk` clock domain,
    // so the AXI-L control interfaces from the decoder can be directly
    // connected:
    // -------------------------------------------------------------------------

    // Local signal declarations
    logic        valid_0_1;
    logic [31:0] data_0_1;
    logic        valid_1_0;
    logic [31:0] data_1_0;

    // Instiate components, connecting component 0 outputs to component 1 inputs
    // and vice versa
    example_component i_example_component_0 (
        .clk          ( axil_if.aclk ),
        .axil_if      ( axil_if_component_0 ),
        .input_valid  ( valid_1_0 ),
        .input_data   ( data_1_0  ),
        .output_valid ( valid_0_1 ),
        .output_data  ( data_0_1  )
    );

    example_component i_example_component_1 (
        .clk          ( axil_if.aclk ),
        .axil_if      ( axil_if_component_1 ),
        .input_valid  ( valid_0_1 ),
        .input_data   ( data_0_1  ),
        .output_valid ( valid_1_0 ),
        .output_data  ( data_1_0  )
    );

    // -------------------------------------------------------------------------
    // Component 2 operates synchronously to the `clk` clock domain, (and
    // asynchronously to the `axil_if.aclk` domain. Synchronization here is
    // achieved by synchronizing the entire `axil_if_component_2` interface
    // using an AXI-L interface synchronizer.
    //
    // NOTE: this is only one of many options for synchronization between
    // datapath and control clock domains. The method shown here results in the
    // register infrastructure comprising the register block instantiated within
    // the `example_component` module to be implemented on the (typically
    // faster) `clk` clock domain. This can cause issues during timing closure.
    //
    // As an alternative, the synchronization could be included within the
    // component definition itself, in which case it might make more sense to
    // keep all of the register infrastructure on the (typically slower)
    // `axil_aclk` clock domain and cross control/status signals between the
    // clock domains only where necessary.
    // -------------------------------------------------------------------------

    // Local signal declarations
    logic        valid_2;
    logic [31:0] data_2;

    // Local interface declarations
    axi4l_intf axil_if_component_2__clk ();

    // AXI-L interface synchronizer
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller  ( axil_if_component_2 ),
        .clk_to_peripheral         ( clk ),
        .axi4l_if_to_peripheral    ( axil_if_component_2__clk )
    );

    // Instantiate component, looping back outputs to inputs
    example_component i_example_component_2 (
        .clk          ( clk ),
        .axil_if      ( axil_if_component_2__clk ),
        .input_valid  ( valid_2 ),
        .input_data   ( data_2  ),
        .output_valid ( valid_2 ),
        .output_data  ( data_2  )
    );

endmodule : example_top
