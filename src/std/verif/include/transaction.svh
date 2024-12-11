// Base transaction class for verification
// - abstract class (can't instantiated directly)
// - describes interface for 'generic' transactions, where methods are to be implemented by subclass
virtual class transaction extends base;

    local static const string __CLASS_NAME = "std_verif_pkg::transaction";

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    // Get string representation
    pure virtual function automatic string to_string();
    // (Deep) Copy implementation
    pure virtual protected function automatic void _copy(input transaction t2);
    // Compare transactions; return 1 if equal, 0 otherwise.
    pure virtual function automatic bit compare(input transaction t2, output string msg);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="transaction");
        super.new(name);
    endfunction

    // Copy
    function automatic void copy(input transaction t2);
        trace_msg("copy()");
        super.copy(t2);
        this._copy(t2);
        trace_msg("copy() Done.");
    endfunction

    // Clone
    function automatic transaction clone();
        transaction t2 = new this;
        trace_msg("clone()");
        t2.copy(this);
        trace_msg("clone() Done.");
        return t2;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

endclass : transaction
