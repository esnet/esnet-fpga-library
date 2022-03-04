// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Peter Bengough hereinafter the Contractor, under Contract No.
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

class axi4s_sample #(
    parameter int DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
);

    //===================================
    // Properties
    //===================================
    bit __BIGENDIAN;

    //===================================
    // Interfaces
    //===================================
    virtual axi4s_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
        .TID_T(TID_T),
        .TDEST_T(TDEST_T),
        .TUSER_T(TUSER_T)
    ) axis_vif;

    //===================================
    // Typedefs
    //===================================
    typedef bit [DATA_BYTE_WID-1:0][7:0] tdata_t;
    typedef bit [DATA_BYTE_WID-1:0]      tkeep_t;

    // Constructor
    function new(input bit BIGENDIAN=1);
        __BIGENDIAN = BIGENDIAN;
    endfunction

    task capture_pkt_data(output byte data[$]);
        bit [DATA_BYTE_WID-1:0][7:0] tdata;
        bit [DATA_BYTE_WID-1:0] tkeep;
        bit tlast = 0;
        TID_T tid;
        TDEST_T tdest;
        TUSER_T tuser;

        int byte_idx = 0;

        while (!tlast) begin
            @(negedge axis_vif.aclk) axis_vif.sample(tdata, tkeep, tlast, tid, tdest, tuser);
            if (__BIGENDIAN) begin
                tdata = {<<byte{tdata}};
                tkeep = {<<{tkeep}};
            end
            while (byte_idx < DATA_BYTE_WID) begin
                if (tkeep[byte_idx]) data.push_back(tdata[byte_idx]);
                byte_idx++;
	    end
	    byte_idx = 0;
        end 
    endtask 

endclass
