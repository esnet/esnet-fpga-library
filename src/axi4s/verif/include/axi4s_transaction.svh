class axi4s_transaction #(
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
) extends packet_verif_pkg::packet_transaction;

    local static const string __CLASS_NAME = "axi4s_verif_pkg::axi4s_transaction";

    //===================================
    // Properties
    //===================================
    const TID_T   tid;
    const TDEST_T tdest;
    const TUSER_T tuser;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="axi4s_transaction",
            input packet_verif_pkg::packet packet,
            input TID_T tid=0,
            input TDEST_T tdest=0,
            input TUSER_T tuser=0
        );
        super.new(name, packet);
        this.tid = tid;
        this.tdest = tdest;
        this.tuser = tuser;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Get string representation of transaction
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    function string to_string();
        string str = $sformatf("AXI4-S transaction: %s\n", get_name());
        str = {str, "------------------------------------------\n"};
        str = {str, "Metadata:\n"};
        str = {str, $sformatf("TID: %x, TDEST: %x, TUSER: %x\n", this.tid, this.tdest, this.tuser)};
        str = {str, "------------------------------------------\n"};
        str = {str, get_packet().to_string()};
        return str;
    endfunction

    // Compare transaction to a reference transaction
    // [[ implements std_verif_pkg::transaction.compare() ]]
    function bit compare(input axi4s_transaction#(TID_T,TDEST_T,TUSER_T) t2, output string msg);
        if (!get_packet().compare(t2.get_packet(), msg)) begin
            return 0;
        end else if (this.tid != t2.tid) begin
            msg = $sformatf("Mismatch in 'tid' field. A: %x, B: %x.", this.tid, t2.tid);
            return 0;
        end else if (this.tdest != t2.tdest) begin
            msg = $sformatf("Mismatch in 'tdest' field. A: %x, B: %x.", this.tdest, t2.tdest);
            return 0;
        end else if (this.tuser != t2.tuser) begin
            msg = $sformatf("Mismatch in 'tuser' field. A: %x, B: %x.", this.tuser, t2.tuser);
            return 0;
        end else begin
            msg = "Transactions match.";
            return 1;
        end
    endfunction
endclass
