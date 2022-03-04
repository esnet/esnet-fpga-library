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
