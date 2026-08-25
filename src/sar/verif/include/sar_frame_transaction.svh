// SAR frame transaction
// - represents a complete reassembled/to-be-segmented frame
// - identified by buf_id; carries raw byte data
class sar_frame_transaction #(
    parameter type BUF_ID_T = bit
) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "sar_verif_pkg::sar_frame_transaction";

    //===================================
    // Properties
    //===================================
    BUF_ID_T   buf_id;
    rand byte  data[];
    bit        out_of_order;
    bit        error;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string  name   = "sar_frame_transaction",
            input BUF_ID_T buf_id = '0,
            input int      len    = 0
        );
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        this.buf_id       = buf_id;
        this.data         = new[len];
        this.out_of_order = 1'b0;
        this.error        = 1'b0;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Return frame size in bytes
    function automatic int size();
        return data.size();
    endfunction

    // Copy from reference
    // [[ implements std_verif_pkg::transaction._copy() ]]
    virtual protected function automatic void _copy(input std_verif_pkg::transaction t2);
        sar_frame_transaction#(BUF_ID_T) t;
        super._copy(t2);
        if (!$cast(t, t2)) begin
            $fatal(2, $sformatf("Type mismatch while copying '%s' to '%s'", t2.get_name(), this.get_name()));
        end
        this.buf_id       = t.buf_id;
        this.data         = new[t.data.size()](t.data);
        this.out_of_order = t.out_of_order;
        this.error        = t.error;
    endfunction

    // Get string representation
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    function automatic string to_string();
        string str;
        str  = $sformatf("SAR frame transaction '%s'\n", get_name());
        str  = {str, "------------------------------------------\n"};
        str  = {str, $sformatf("buf_id: 0x%0x, len: %0d\n", buf_id, data.size())};
        if (data.size() > 0) begin
            int show = (data.size() < 8) ? data.size() : 8;
            str = {str, "data (first bytes): "};
            for (int i = 0; i < show; i++)
                str = {str, $sformatf("%02x ", data[i])};
            str = {str, "...\n"};
        end
        str  = {str, "------------------------------------------\n"};
        return str;
    endfunction

    // Compare against another transaction
    // [[ implements std_verif_pkg::transaction.compare() ]]
    virtual function automatic bit compare(input std_verif_pkg::transaction t2, output string msg);
        sar_frame_transaction#(BUF_ID_T) b;
        if (!$cast(b, t2)) begin
            msg = $sformatf("Transaction type mismatch. '%s' is not sar_frame_transaction with matching parameterization.", t2.get_name());
            return 0;
        end
        if (this.buf_id !== b.buf_id) begin
            msg = $sformatf("Mismatch in 'buf_id'. A: 0x%0x, B: 0x%0x.", this.buf_id, b.buf_id);
            return 0;
        end
        if (this.data.size() !== b.data.size()) begin
            msg = $sformatf("Mismatch in frame length. A: %0d, B: %0d.", this.data.size(), b.data.size());
            return 0;
        end
        foreach (this.data[i]) begin
            if (this.data[i] !== b.data[i]) begin
                msg = $sformatf("Mismatch at byte %0d. A: 0x%02x, B: 0x%02x.", i, this.data[i], b.data[i]);
                return 0;
            end
        end
        msg = "SAR frame transactions match.";
        return 1;
    endfunction

endclass : sar_frame_transaction
