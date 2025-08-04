class axi4s_sample #(
    parameter int DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
);

    //===================================
    // Interfaces
    //===================================
    virtual axi4s_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
        .TID_T  (logic[$bits(TID_T)-1:0]),
        .TDEST_T(logic[$bits(TDEST_T)-1:0]),
        .TUSER_T(logic[$bits(TUSER_T)-1:0])
    ) axis_vif;

    //===================================
    // Typedefs
    //===================================
    typedef bit [DATA_BYTE_WID-1:0][7:0] tdata_t;
    typedef bit [DATA_BYTE_WID-1:0]      tkeep_t;

    // Constructor
    function new();
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
            while (byte_idx < DATA_BYTE_WID) begin
                if (tkeep[byte_idx]) data.push_back(tdata[byte_idx]);
                byte_idx++;
	    end
	    byte_idx = 0;
        end 
    endtask 

endclass
