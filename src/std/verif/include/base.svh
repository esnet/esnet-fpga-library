// Base class for verif components
// - abstract class (can't be instantiated directly)
// - describes interface for 'base' components, where methods are to be implemented by subclass
virtual class base;

    local static const string __CLASS_NAME = "std_verif_pkg::base";

    //===================================
    // Properties
    //===================================
    local string __obj_name;

    local int __DEBUG_LEVEL = 0;

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    // Destructor
    pure virtual function automatic void destroy();

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="base");
        this.__obj_name = name;
    endfunction

    // Configure trace output
    // (should be overriden by derived classes)
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    function automatic string get_name();
        return this.__obj_name;
    endfunction

    function automatic void set_name(input string name);
        this.__obj_name = name;
    endfunction

    function automatic void set_debug_level(input int DEBUG_LEVEL);
        this.__DEBUG_LEVEL = DEBUG_LEVEL;
    endfunction

    function automatic int get_debug_level();
        return this.__DEBUG_LEVEL;
    endfunction

    protected function automatic void _trace_msg(input string msg, input string hier_path="");
        if (this.__DEBUG_LEVEL > 2) print_msg("TRACE:", get_name(), {"--- ", msg, " ---"}, hier_path);
    endfunction

    function automatic void debug_msg(input string msg);
        if (this.__DEBUG_LEVEL > 1) print_msg("DEBUG:", get_name(), msg);
    endfunction

    function automatic void info_msg(input string msg);
        if (this.__DEBUG_LEVEL > 0) print_msg("INFO: ", get_name(), msg);
    endfunction

    function automatic void error_msg(input string msg);
        print_msg("ERROR:", get_name(), msg);
    endfunction

    static function automatic void print_msg(input string label, input string name, input string msg, input string hier_path="");
        if (hier_path == "") $display("%s [%0t][%s]: %s", label, $time, name, msg);
        else                 $display("%s [%0t][%s][%s]: %s", label, $time, name, hier_path, msg);
    endfunction

endclass
