module reg_endian_check
#(
) (
    // AXI4-Lite control interface
    axi4l_intf.peripheral      axil_if
);

    // Local interfaces
    reg_endian_check_reg_intf reg_endian_check_reg_if ();

    // Endian check register block
    reg_endian_check_reg_blk i_reg_endian_check_reg_blk (
        .axil_if     (axil_if),
        .reg_blk_if  (reg_endian_check_reg_if)
    );

    // Unpack 'packed' scratchpad and connect to byte monitors
    assign reg_endian_check_reg_if.scratchpad_packed_monitor_byte_0_nxt_v = 1'b1;
    assign reg_endian_check_reg_if.scratchpad_packed_monitor_byte_0_nxt = reg_endian_check_reg_if.scratchpad_packed[7:0];

    assign reg_endian_check_reg_if.scratchpad_packed_monitor_byte_1_nxt_v = 1'b1;
    assign reg_endian_check_reg_if.scratchpad_packed_monitor_byte_1_nxt = reg_endian_check_reg_if.scratchpad_packed[15:8];

    assign reg_endian_check_reg_if.scratchpad_packed_monitor_byte_2_nxt_v = 1'b1;
    assign reg_endian_check_reg_if.scratchpad_packed_monitor_byte_2_nxt = reg_endian_check_reg_if.scratchpad_packed[23:16];

    assign reg_endian_check_reg_if.scratchpad_packed_monitor_byte_3_nxt_v = 1'b1;
    assign reg_endian_check_reg_if.scratchpad_packed_monitor_byte_3_nxt = reg_endian_check_reg_if.scratchpad_packed[31:24];

    // Pack 'unpack' scratchpad and connect to reg monitor
    assign reg_endian_check_reg_if.scratchpad_unpacked_monitor_nxt_v = 1'b1;
    assign reg_endian_check_reg_if.scratchpad_unpacked_monitor_nxt = {
        reg_endian_check_reg_if.scratchpad_unpacked_byte_3,
        reg_endian_check_reg_if.scratchpad_unpacked_byte_2,
        reg_endian_check_reg_if.scratchpad_unpacked_byte_1,
        reg_endian_check_reg_if.scratchpad_unpacked_byte_0
    };

endmodule : reg_endian_check
