module pci_vpd_card_info_intf_cdc_wrapper (
    input  logic       provider_clk,
    input  logic       provider_srst,
    input  logic       provider_vld,
    input  logic       provider_error,
    input  logic [8:0] provider_len,
    output logic       provider_rd,
    output logic [8:0] provider_rd_addr,
    input  logic [7:0] provider_rd_data,
    input  logic       provider_rd_vld,
    input  logic       consumer_clk,
    input  logic       consumer_srst,
    output logic       consumer_vld,
    output logic       consumer_error,
    output logic [8:0] consumer_len,
    input  logic       consumer_rd,
    input  logic [8:0] consumer_rd_addr,
    output logic [7:0] consumer_rd_data,
    output logic       consumer_rd_vld
);
    pci_vpd_card_info_intf provider_if (.clk(provider_clk));
    pci_vpd_card_info_intf consumer_if (.clk(consumer_clk));

    assign provider_if.srst = provider_srst;
    assign provider_if.vld = provider_vld;
    assign provider_if.error = provider_error;
    assign provider_if.len = provider_len;
    assign provider_rd = provider_if.rd;
    assign provider_rd_addr = provider_if.rd_addr;
    assign provider_if.rd_data = provider_rd_data;
    assign provider_if.rd_vld = provider_rd_vld;
    assign consumer_vld = consumer_if.vld;
    assign consumer_error = consumer_if.error;
    assign consumer_len = consumer_if.len;
    assign consumer_if.rd = consumer_rd;
    assign consumer_if.rd_addr = consumer_rd_addr;
    assign consumer_rd_data = consumer_if.rd_data;
    assign consumer_rd_vld = consumer_if.rd_vld;

    pci_vpd_card_info_intf_cdc i_pci_vpd_card_info_intf_cdc (
        .consumer_srst,
        .card_info_if_from_provider ( provider_if ),
        .card_info_if_to_consumer   ( consumer_if )
    );
endmodule : pci_vpd_card_info_intf_cdc_wrapper
