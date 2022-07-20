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
    protected bit _BIGENDIAN;

    local int _tpause;

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
        this._BIGENDIAN = BIGENDIAN;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset monitor state
    // [[ implements _reset() virtual method of std_verif_pkg::monitor parent class ]]
    function automatic void _reset();
        // Nothing to do
    endfunction

    // Put AXI-S monitor interface in idle state
    // [[ implements std_verif_pkg::monitor.idle() ]]
    task idle();
        axis_vif.idle_rx();
    endtask

    // Wait for specified number of 'cycles' on the monitored interface
    // [[ implements std_verif_pkg::monitor._wait() ]]
    task _wait(input int cycles);
        axis_vif._wait(cycles);
    endtask

    // Set tpause value used by monitor (for stalling receive transactions)
    function automatic void set_tpause(input int tpause);
        this._tpause = tpause;
    endfunction

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
            if (_BIGENDIAN) begin
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
    // [[ implements _receive() virtual method of std_verif_pkg::monitor parent class ]]
    // [[ implements std_verif_pkg::monitor._receive() ]]
    task _receive(
            output axi4s_transaction#(TID_T, TDEST_T, TUSER_T) transaction
        );
        // Signals
        byte data [];
        TID_T tid;
        TDEST_T tdest;
        TUSER_T tuser;

        packet_verif_pkg::packet_raw packet;

        debug_msg("Waiting for transaction...");

        // Receive transaction
        receive_raw(data, tid, tdest, tuser, _tpause);

        // Build Rx packet transaction
        packet = packet_verif_pkg::packet_raw::create_from_bytes("rx_packet", data);

        // Build Rx AXI-S transaction
        transaction = new("rx_axi4s_transaction", packet, tid, tdest, tuser);

        debug_msg($sformatf("Received %s (%0d bytes).", transaction.get_name(), transaction.get_packet().size()));
    endtask

    task flush();
        axis_vif.tready = 1'b1;
    endtask

endclass
