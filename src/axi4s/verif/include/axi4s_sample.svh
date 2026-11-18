class axi4s_sample #(
    parameter int DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
);

    localparam int TID_WID = $bits(TID_T);
    localparam int TDEST_WID = $bits(TDEST_T);
    localparam int TUSER_WID = $bits(TUSER_T);

    //===================================
    // Interfaces
    //===================================
    virtual axi4s_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
        .TID_WID  ($bits(TID_T)),
        .TDEST_WID($bits(TDEST_T)),
        .TUSER_WID($bits(TUSER_T))
    ) axis_vif;

    //===================================
    // Typedefs
    //===================================
    typedef bit [DATA_BYTE_WID-1:0][7:0] tdata_t;
    typedef bit [DATA_BYTE_WID-1:0]      tkeep_t;

    // Constructor
    function new();
        axis_vif = null;
    endfunction

    //===================================
    // Clocking-block interface control and transfers
    //===================================
    task wait_n(input int cycles);
        repeat (cycles) @(axis_vif.cb);
    endtask

    task sample_beat(
            output bit [DATA_BYTE_WID-1:0][7:0] _tdata,
            output bit [DATA_BYTE_WID-1:0]      _tkeep,
            output bit                          _tlast,
            output bit [TID_WID-1:0]            _tid,
            output bit [TDEST_WID-1:0]          _tdest,
            output bit [TUSER_WID-1:0]          _tuser
        );
        do @(axis_vif.cb); while (!(axis_vif.cb.tvalid && axis_vif.cb.tready));
        _tdata = axis_vif.cb.tdata;
        _tkeep = axis_vif.cb.tkeep;
        _tlast = axis_vif.cb.tlast;
        _tid = axis_vif.cb.tid;
        _tdest = axis_vif.cb.tdest;
        _tuser = axis_vif.cb.tuser;
    endtask

    // Assemble accepted bytes without driving readiness.
    task capture_pkt_data(output byte data[$]);
        bit [DATA_BYTE_WID-1:0][7:0] tdata;
        bit [DATA_BYTE_WID-1:0] tkeep;
        bit tlast = 0;
        TID_T tid;
        TDEST_T tdest;
        TUSER_T tuser;

        int byte_idx = 0;

        while (!tlast) begin
            sample_beat(tdata, tkeep, tlast, tid, tdest, tuser);
            while (byte_idx < DATA_BYTE_WID) begin
                if (tkeep[byte_idx]) data.push_back(tdata[byte_idx]);
                byte_idx++;
            end
            byte_idx = 0;
        end
    endtask

endclass
