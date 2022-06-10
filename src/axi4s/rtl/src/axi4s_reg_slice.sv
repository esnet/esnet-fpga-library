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

module axi4s_reg_slice
    import axi4s_pkg::*;
#(
    parameter int  DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit,
    parameter xilinx_reg_slice_config_t CONFIG = REG_SLICE_DEFAULT
) (
    axi4s_intf.rx axi4s_from_tx,
    axi4s_intf.tx axi4s_to_rx
);

    // Conversion from config enum to Xilinx config value
    function automatic int getRegConfig(input xilinx_reg_slice_config_t _config);
        case (_config)
            REG_SLICE_BYPASS             : return 0;
            REG_SLICE_DEFAULT            : return 1;
            REG_SLICE_LIGHTWEIGHT        : return 7;
            REG_SLICE_FULLY_REGISTERED   : return 8;
            REG_SLICE_SLR_CROSSING       : return 12;
//          REG_SLICE_SLR_TDM_CROSSING   : return 13; // Unsupported
//          REG_SLICE_MULTI_SLR_CROSSING : return 15; // Unsupported
            REG_SLICE_AUTO_PIPELINED     : return 16;
            REG_SLICE_PRESERVE_SI        : return 17;
            REG_SLICE_PRESERVE_MI        : return 18;
            default                      : return 1;
        endcase
    endfunction

    function automatic int getResetPipeStages(input xilinx_reg_slice_config_t _config);
        case (_config)
            REG_SLICE_BYPASS       : return 0;
            REG_SLICE_SLR_CROSSING : return 3;
            default                : return 1;
        endcase
    endfunction

    // Xilinx AXI-S register slice
    axis_register_slice_v1_1_26_axis_register_slice #(
        .C_FAMILY            ("virtexuplusHBM"),
        .C_AXIS_TDATA_WIDTH  (DATA_BYTE_WID*8),
        .C_AXIS_TID_WIDTH    ($bits(TID_T)),
        .C_AXIS_TDEST_WIDTH  ($bits(TDEST_T)),
        .C_AXIS_TUSER_WIDTH  ($bits(TUSER_T)),
        .C_AXIS_SIGNAL_SET   (32'b00000000000000000000000001111011),
        .C_REG_CONFIG        (getRegConfig(CONFIG)),
        .C_NUM_SLR_CROSSINGS (0),
        .C_PIPELINES_MASTER  (0),
        .C_PIPELINES_SLAVE   (0),
        .C_PIPELINES_MIDDLE  (0)
    ) inst (
        .aclk          ( axi4s_from_tx.aclk ),
        .aclk2x        ( 1'b0 ),
        .aresetn       ( axi4s_from_tx.aresetn ),
        .aclken        ( 1'b1 ),
        .s_axis_tvalid ( axi4s_from_tx.tvalid ),
        .s_axis_tready ( axi4s_from_tx.tready ),
        .s_axis_tdata  ( axi4s_from_tx.tdata ),
        .s_axis_tstrb  ( '1 ),
        .s_axis_tkeep  ( axi4s_from_tx.tkeep ),
        .s_axis_tlast  ( axi4s_from_tx.tlast ),
        .s_axis_tid    ( axi4s_from_tx.tid ),
        .s_axis_tdest  ( axi4s_from_tx.tdest ),
        .s_axis_tuser  ( axi4s_from_tx.tuser ),
        .m_axis_tvalid ( axi4s_to_rx.tvalid ),
        .m_axis_tready ( axi4s_to_rx.tready ),
        .m_axis_tdata  ( axi4s_to_rx.tdata ),
        .m_axis_tstrb  ( ),
        .m_axis_tkeep  ( axi4s_to_rx.tkeep ),
        .m_axis_tlast  ( axi4s_to_rx.tlast ),
        .m_axis_tid    ( axi4s_to_rx.tid ),
        .m_axis_tdest  ( axi4s_to_rx.tdest ),
        .m_axis_tuser  ( axi4s_to_rx.tuser)
    );

    assign axi4s_to_rx.aclk = axi4s_from_tx.aclk;

    // Pipeline reset
    util_pipe       #(
        .DATA_T      ( logic ),
        .PIPE_STAGES ( getResetPipeStages(CONFIG) )
    ) i_util_pipe_aresetn (
        .clk      ( axi4s_to_rx.aclk ),
        .srst     ( 1'b0 ),
        .data_in  ( axi4s_from_tx.aresetn ),
        .data_out ( axi4s_to_rx.aresetn )
    );


endmodule : axi4s_reg_slice
