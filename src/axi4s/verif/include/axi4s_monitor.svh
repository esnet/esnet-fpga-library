class axi4s_monitor #(
    parameter int DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
) extends std_verif_pkg::monitor#(axi4s_transaction#(TID_T, TDEST_T, TUSER_T));

    local static const string __CLASS_NAME = "axi4s_verif_pkg::axi4s_monitor";

    //===================================
    // Properties
    //===================================
    local bit __BIGENDIAN;
    local int __tpause = 0;

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
    function new(input string name="axi4s_monitor", input bit BIGENDIAN=1);
        super.new(name);
        this.__BIGENDIAN = BIGENDIAN;
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        axis_vif = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set tpause value used by monitor (for stalling receive transactions)
    function automatic void set_tpause(input int tpause);
        this.__tpause = tpause;
    endfunction

    // Reset monitor
    // [[ overrides std_verif_pkg::monitor._reset() ]]
    virtual protected function automatic void _reset();
        super._reset();
        this.set_tpause(0);
    endfunction

    // Quiesce AXI-S interface
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        super._idle();
        axis_vif.idle_rx();
    endtask

    // Receive transaction (represented as raw byte array with associated metadata)
    task receive_raw(
            output byte    data[$],
            output TID_T   id,
            output TDEST_T dest,
            output TUSER_T user,
            input  int     tpause = 0
        );
        // Signals
        bit [DATA_BYTE_WID-1:0][7:0] tdata;
        bit [DATA_BYTE_WID-1:0] tkeep;
        bit tlast = 0;
        int byte_idx = 0;
        int word_idx = 0;
        int byte_cnt = 0;
        TID_T tid;
        TDEST_T tdest;
        TUSER_T tuser;

        debug_msg("receive_raw: Waiting for data...");

        while (!tlast) begin
            axis_vif.receive(tdata, tkeep, tlast, tid, tdest, tuser, tpause);
            trace_msg($sformatf("receive_raw: Received word %0d.", word_idx));
            if (this.__BIGENDIAN) begin
                tdata = {<<byte{tdata}};
                tkeep = {<<{tkeep}};
            end

            while (byte_idx < DATA_BYTE_WID) begin
                if (tkeep[byte_idx]) data.push_back(tdata[byte_idx]);
                byte_idx++;
            end
            byte_cnt += byte_idx;
            byte_idx = 0;
            word_idx++;
        end
        debug_msg($sformatf("receive_raw: Done. Received %0d bytes.", byte_cnt));
        id = tid;
        dest = tdest;
        user = tuser;
    endtask


    // Receive AXI-S transaction from AXI-S bus
    // [[ implements std_verif_pkg::monitor._receive() ]]
    protected task _receive(output axi4s_transaction#(TID_T, TDEST_T, TUSER_T) transaction);
        // Signals
        byte data [];
        TID_T tid;
        TDEST_T tdest;
        TUSER_T tuser;

        debug_msg("Waiting for transaction...");

        // Receive transaction
        receive_raw(data, tid, tdest, tuser, this.__tpause);

        // Build Rx AXI-S transaction
        transaction = axi4s_transaction#(TID_T, TDEST_T, TUSER_T)::create_from_bytes(
            "rx_axi4s_transaction",
            data,
            tid,
            tdest,
            tuser
        );

        debug_msg($sformatf("Received %s (%0d bytes).", transaction.get_name(), transaction.size()));
    endtask

    task flush();
        axis_vif.tready = 1'b1;
    endtask

endclass
