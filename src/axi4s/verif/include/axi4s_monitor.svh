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

    //===================================
    // Properties
    //===================================
    protected bit _BIGENDIAN;

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

    // Reset monitor state
    // [[ implements _reset() virtual method of std_verif_pkg::monitor parent class ]]
    function automatic void _reset();
        // Nothing to do
    endfunction

    // Put AXI-S monitor interface in idle state
    // [[ implements idle() virtual method of std_verif_pkg::monitor parent class ]]
    task idle();
        axis_vif.idle_rx();
    endtask

    // Wait for specified number of 'cycles' on the monitored interface
    // [[ implements _wait() virtual method of std_verif_pkg::monitor parent class ]]
    task _wait(input int cycles);
        axis_vif._wait(cycles);
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
        TID_T tid;
        TDEST_T tdest;
        TUSER_T tuser;

        while (!tlast) begin
            axis_vif.receive(tdata, tkeep, tlast, tid, tdest, tuser, tpause);
            if (_BIGENDIAN) begin
                tdata = {<<byte{tdata}};
                tkeep = {<<{tkeep}};
            end

            while (byte_idx < DATA_BYTE_WID) begin
                if (tkeep[byte_idx]) data.push_back(tdata[byte_idx]);
                byte_idx++;
            end
            byte_idx = 0;
        end
        id = tid;
        dest = tdest;
        user = tuser;
    endtask


    // Send AXI-S transaction on AXI-S bus
    // [[ implements receive() virtual method of std_verif_pkg::monitor parent class ]]
    task receive(
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
        receive_raw(data, tid, tdest, tuser);

        // Build Rx packet transaction
        packet = new("Rx packet", data);

        // Build Rx AXI-S transaction
        transaction = new(packet.get_name(), packet, tid, tdest, tuser);

        debug_msg($sformatf("Received %s (%0d bytes).", transaction.get_name(), transaction.get_packet().size()));
    endtask

    task flush();
        axis_vif.tready = 1'b1;
    endtask

endclass
