// Base transaction class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' transactions, where methods are to be
//   implemented by sublass
class transaction extends base;

    local static const string __CLASS_NAME = "std_verif_pkg::transaction";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="transaction");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // String representation
    virtual function automatic string to_string(); endfunction
    // Compare transaction
    virtual function automatic bit compare(input transaction t2, output string msg); endfunction

endclass
