// Base class for verif components
// - abstract class (can't be instantiated directly)
// - describes interface for 'base' components, where methods are to be implemented by subclass
virtual class base;

    local static const string __CLASS_NAME = "std_verif_pkg::base";

    //===================================
    // Properties
    //===================================
    // WORKAROUND-STRING-PROP {
    //     Store object name as array of bytes instead of string to
    //     work around copy constructor issue, i.e. unexpected
    //     interaction between original and copied object through
    //     the __obj_name property (new string object not allocated
    //     or improperly allocated for copied object?).
    //
    //     Interface for accessing this value as a string is unchanged
    //     (i.e. get_name/set_name return/accept string variables).
    // local string __obj_name;
    local byte __obj_name [];
    // } WORKAROUND-STRING-PROP

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
        set_name(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        __DEBUG_LEVEL = 0;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Copy
    function automatic void copy(input base obj);
        this.set_name(obj.get_name());
        this.set_debug_level(obj.get_debug_level());
    endfunction

    // Configure trace output
    // (should be overriden by derived classes)
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    function automatic string get_name();
        // WORKAROUND-STRING-PROP {
        //     Store object name as array of bytes instead of string to
        //     work around copy constructor issue, i.e. unexpected
        //     interaction between original and copied object through
        //     the __obj_name property (new string object not allocated
        //     or improperly allocated for copied object?).
        //
        //     Interface for accessing this value as a string is unchanged
        //     (i.e. get_name/set_name return/accept string variables).
        // return this.__obj_name;
        return {<<byte{this.__obj_name}};
        // } WORKAROUND-STRING-PROP
    endfunction

    function automatic void set_name(input string name);
        // WORKAROUND-STRING-PROP {
        //     Store object name as array of bytes instead of string to
        //     work around copy constructor issue, i.e. unexpected
        //     interaction between original and copied object through
        //     the __obj_name property (new string object not allocated
        //     or improperly allocated for copied object?).
        //
        //     Interface for accessing this value as a string is unchanged
        //     (i.e. get_name/set_name return/accept string variables).
        // this.__obj_name = name;
        this.__obj_name = {<<byte{name}};
        // } WORKAROUND-STRING-PROP
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
