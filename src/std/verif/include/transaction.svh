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
    // Compare transactions; return 1 if equal, 0 otherwise.
    pure virtual function automatic bit compare(input transaction t2, output string msg);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="transaction");
        super.new(name);
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

endclass : transaction
