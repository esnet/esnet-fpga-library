package crc_verif_pkg;

    // ========================================================
    //  Parameters
    // ========================================================
    parameter string CHECK_STRING = "123456789";
    parameter int CHECK_STRING_LEN = CHECK_STRING.len();

    // ========================================================
    // Typedefs
    // ========================================================
    typedef bit[31:0] CRC_T;

    // ========================================================
    // Functions
    // ========================================================
    function automatic CRC_T calculate (
            input int   width,
            input CRC_T poly,
            input CRC_T init,
            input bit refin,
            input bit refout,
            input CRC_T xorout,
            input byte data []
        );
        automatic CRC_T crc = init;
        automatic byte data_refin [$];
        automatic CRC_T crc_mask = 2**width-1;

        foreach (data[i]) begin
            bit[7:0] data_byte;
            if (refin) data_byte = {<<{data[i]}};
            else       data_byte = data[i];
            //$display("DATA[%0d]: %x", i, data_byte);
            for (int j = 7; j >= 0; j--) begin
                if (crc[width-1] ^ data_byte[j]) crc = (crc << 1) ^ poly;
                else                             crc = (crc << 1);
                crc = crc & crc_mask;
            end
            //$display("CRC: %x", crc);
        end

        if (refout) begin
            crc = {<<{crc}};
            crc = crc >> (32 - width);
        end

        //$display("CRC: %x, XOROUT: %x", crc, xorout);
        crc = crc ^ xorout;
        //$display("CRC: %x", crc);
        return crc;
    endfunction

endpackage : crc_verif_pkg
