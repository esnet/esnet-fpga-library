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

// Base class for verif components
class base;
    //===================================
    // Properties
    //===================================
    string _name;
    int _DEBUG_LEVEL=0;

    //===================================
    // Methods
    //===================================
    function new(input string name="component");
        this._name = name;
    endfunction

    function automatic string get_name();
        return this._name;
    endfunction

    function automatic string to_string();
        return get_name();
    endfunction

    function automatic void set_debug_level(int DEBUG_LEVEL);
        this._DEBUG_LEVEL = DEBUG_LEVEL;
    endfunction

    function automatic int get_debug_level();
        return this._DEBUG_LEVEL;
    endfunction

    function automatic void debug_msg(string debug_msg);
        if (this._DEBUG_LEVEL > 1) $display($sformatf("[%t][%s] DEBUG: %s", $time, this._name, debug_msg));
    endfunction

    function automatic void info_msg(string info_msg);
        if (this._DEBUG_LEVEL > 0) $display($sformatf("[%t][%s] INFO: %s", $time, this._name, info_msg));
    endfunction

    function automatic void error_msg(string error_msg);
        $display($sformatf("[%t][%s] ERROR: %s", $time, this._name, error_msg));
    endfunction


endclass
