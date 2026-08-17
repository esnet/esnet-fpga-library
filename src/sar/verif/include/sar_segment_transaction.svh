// SAR segment transaction
// - represents one segment of a SAR frame, with sideband metadata
// - carries: buf_id (which frame buffer), offset (byte position in frame),
//   last (final segment flag), and raw byte data
class sar_segment_transaction #(
    parameter type BUF_ID_T = bit,
    parameter type OFFSET_T = bit
) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "sar_verif_pkg::sar_segment_transaction";

    //===================================
    // Properties
    //===================================
    BUF_ID_T  buf_id;
    OFFSET_T  offset;
    bit       last;
    rand byte data[];

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string   name   = "sar_segment_transaction",
            input BUF_ID_T buf_id = '0,
            input OFFSET_T offset = '0,
            input bit      last   = 1'b0,
            input int      len    = 0
        );
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        this.buf_id = buf_id;
        this.offset = offset;
        this.last   = last;
        this.data   = new[len];
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

    // Return segment size in bytes
    function automatic int size();
        return data.size();
    endfunction

    // Copy from reference
    // [[ implements std_verif_pkg::transaction._copy() ]]
    virtual protected function automatic void _copy(input std_verif_pkg::transaction t2);
        sar_segment_transaction#(BUF_ID_T, OFFSET_T) t;
        super._copy(t2);
        if (!$cast(t, t2)) begin
            $fatal(2, $sformatf("Type mismatch while copying '%s' to '%s'", t2.get_name(), this.get_name()));
        end
        this.buf_id = t.buf_id;
        this.offset = t.offset;
        this.last   = t.last;
        this.data   = new[t.data.size()](t.data);
    endfunction

    // Get string representation
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    function automatic string to_string();
        string str;
        str  = $sformatf("SAR segment transaction '%s'\n", get_name());
        str  = {str, "------------------------------------------\n"};
        str  = {str, $sformatf("buf_id: 0x%0x, offset: %0d, last: %0b, len: %0d\n", buf_id, offset, last, data.size())};
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
        sar_segment_transaction#(BUF_ID_T, OFFSET_T) b;
        if (!$cast(b, t2)) begin
            msg = $sformatf("Transaction type mismatch. '%s' is not sar_segment_transaction with matching parameterization.", t2.get_name());
            return 0;
        end
        if (this.buf_id !== b.buf_id) begin
            msg = $sformatf("Mismatch in 'buf_id'. A: 0x%0x, B: 0x%0x.", this.buf_id, b.buf_id);
            return 0;
        end
        if (this.offset !== b.offset) begin
            msg = $sformatf("Mismatch in 'offset'. A: %0d, B: %0d.", this.offset, b.offset);
            return 0;
        end
        if (this.last !== b.last) begin
            msg = $sformatf("Mismatch in 'last'. A: %0b, B: %0b.", this.last, b.last);
            return 0;
        end
        if (this.data.size() !== b.data.size()) begin
            msg = $sformatf("Mismatch in segment length. A: %0d, B: %0d.", this.data.size(), b.data.size());
            return 0;
        end
        foreach (this.data[i]) begin
            if (this.data[i] !== b.data[i]) begin
                msg = $sformatf("Mismatch at byte %0d. A: 0x%02x, B: 0x%02x.", i, this.data[i], b.data[i]);
                return 0;
            end
        end
        msg = "SAR segment transactions match.";
        return 1;
    endfunction

endclass : sar_segment_transaction
