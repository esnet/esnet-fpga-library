// Transfer a read-only card-info cache between independent clock domains.
// The consumer issues one byte read at a time and waits for its response.
module pci_vpd_card_info_intf_cdc (
    input logic consumer_srst,
    pci_vpd_card_info_intf.consumer card_info_if_from_provider,
    pci_vpd_card_info_intf.provider card_info_if_to_consumer
);

    wire provider_srst = card_info_if_from_provider.srst;

    // =========================================================================
    // Reset both handshake endpoints when either interface is reset
    // =========================================================================
    logic provider_reset = 1'b1;
    logic consumer_reset = 1'b1;
    logic provider_srst__consumer_clk;
    logic consumer_srst__provider_clk;

    sync_reset #(.INPUT_ACTIVE_HIGH(1)) i_sync_reset__provider (
        .clk_in  ( card_info_if_from_provider.clk ),
        .rst_in  ( provider_srst ),
        .clk_out ( card_info_if_to_consumer.clk ),
        .rst_out ( provider_srst__consumer_clk )
    );

    sync_reset #(.INPUT_ACTIVE_HIGH(1)) i_sync_reset__consumer (
        .clk_in  ( card_info_if_to_consumer.clk ),
        .rst_in  ( consumer_srst ),
        .clk_out ( card_info_if_from_provider.clk ),
        .rst_out ( consumer_srst__provider_clk )
    );

    always_ff @(posedge card_info_if_from_provider.clk) begin
        provider_reset <= provider_srst || consumer_srst__provider_clk;
    end

    always_ff @(posedge card_info_if_to_consumer.clk) begin
        consumer_reset <= consumer_srst || provider_srst__consumer_clk;
    end

    assign card_info_if_to_consumer.srst = consumer_reset;

    // =========================================================================
    // Publish availability, error and length as one coherent sample
    // =========================================================================
    sync_bus_sampled #(
        .DATA_WID  ( 11 ),
        .RST_VALUE ( '0 )
    ) i_sync_bus_sampled__status (
        .clk_in   ( card_info_if_from_provider.clk ),
        .rst_in   ( provider_reset ),
        .data_in  ( {card_info_if_from_provider.vld,
                     card_info_if_from_provider.error,
                     card_info_if_from_provider.len} ),
        .clk_out  ( card_info_if_to_consumer.clk ),
        .rst_out  ( consumer_reset ),
        .data_out ( {card_info_if_to_consumer.vld,
                     card_info_if_to_consumer.error,
                     card_info_if_to_consumer.len} )
    );

    // =========================================================================
    // Byte requests
    // =========================================================================
    logic read_pending;
    logic request_sent;
    logic [8:0] request_addr;
    logic request_ready;
    logic request_valid;
    logic request_ack;
    logic [8:0] provider_addr;
    logic response_ack;
    logic [7:0] consumer_data;

    assign request_valid = read_pending && !request_sent;

    always_ff @(posedge card_info_if_to_consumer.clk) begin
        if (consumer_reset) begin
            read_pending <= 1'b0;
            request_sent <= 1'b0;
            request_addr <= '0;
        end else begin
            if (card_info_if_to_consumer.rd && !read_pending) begin
                read_pending <= 1'b1;
                request_sent <= 1'b0;
                request_addr <= card_info_if_to_consumer.rd_addr;
            end
            if (request_valid && request_ready) request_sent <= 1'b1;
            if (response_ack && request_sent) read_pending <= 1'b0;
        end
    end

    sync_bus #(
        .DATA_WID  ( 9 ),
        .RST_VALUE ( '0 )
    ) i_sync_bus__request (
        .clk_in   ( card_info_if_to_consumer.clk ),
        .rst_in   ( consumer_reset ),
        .rdy_in   ( request_ready ),
        .req_in   ( request_valid ),
        .data_in  ( request_addr ),
        .clk_out  ( card_info_if_from_provider.clk ),
        .rst_out  ( provider_reset ),
        .ack_out  ( request_ack ),
        .data_out ( provider_addr )
    );

    logic provider_read_active = 1'b0;
    logic discard_response = 1'b0;
    logic request_queued;
    logic [8:0] queued_addr;

    // A consumer reset invalidates an old read but does not cancel it at the
    // provider. Drain its response before dispatching another byte request.
    always @(posedge card_info_if_from_provider.clk) begin
        card_info_if_from_provider.rd <= 1'b0;
        if (provider_srst) begin
            provider_read_active <= 1'b0;
            discard_response <= 1'b0;
        end else begin
            if (provider_reset && provider_read_active) discard_response <= 1'b1;
            if (card_info_if_from_provider.rd_vld && provider_read_active) begin
                provider_read_active <= 1'b0;
                discard_response <= 1'b0;
            end
            if (!provider_reset && request_queued && !provider_read_active) begin
                card_info_if_from_provider.rd <= 1'b1;
                card_info_if_from_provider.rd_addr <= queued_addr;
                provider_read_active <= 1'b1;
                discard_response <= 1'b0;
            end
        end
        if (provider_reset) begin
            request_queued <= 1'b0;
            queued_addr <= '0;
        end else begin
            if (request_queued && !provider_read_active) request_queued <= 1'b0;
            if (request_ack) begin
                request_queued <= 1'b1;
                queued_addr <= provider_addr;
            end
        end
    end

    // =========================================================================
    // Byte responses; retain pulse-valid provider data until accepted
    // =========================================================================
    logic response_pending;
    logic response_ready;
    logic [7:0] response_data;

    always_ff @(posedge card_info_if_from_provider.clk) begin
        if (provider_reset) begin
            response_pending <= 1'b0;
            response_data <= '0;
        end else begin
            if (response_pending && response_ready) response_pending <= 1'b0;
            if (card_info_if_from_provider.rd_vld && provider_read_active
                && !discard_response) begin
                response_pending <= 1'b1;
                response_data <= card_info_if_from_provider.rd_data;
            end
        end
    end

    sync_bus #(
        .DATA_WID  ( 8 ),
        .RST_VALUE ( '0 )
    ) i_sync_bus__response (
        .clk_in   ( card_info_if_from_provider.clk ),
        .rst_in   ( provider_reset ),
        .rdy_in   ( response_ready ),
        .req_in   ( response_pending ),
        .data_in  ( response_data ),
        .clk_out  ( card_info_if_to_consumer.clk ),
        .rst_out  ( consumer_reset ),
        .ack_out  ( response_ack ),
        .data_out ( consumer_data )
    );

    assign card_info_if_to_consumer.rd_vld = !consumer_reset && read_pending
                                        && request_sent && response_ack;
    assign card_info_if_to_consumer.rd_data = consumer_data;

endmodule : pci_vpd_card_info_intf_cdc
