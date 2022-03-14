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

class raw_transaction #(
    parameter type DATA_T = bit[15:0]
) extends transaction;

    local static const string __CLASS_NAME = "std_verif_pkg::raw_transaction";

    //===================================
    // Properties
    //===================================
    const DATA_T data;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="raw_transaction",
            input DATA_T data
        );
        super.new(name);
        this.data = data;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Get string representation of transaction
    // [[ implements to_string virtual method of std_verif_pkg::transaction ]]
    function automatic string to_string();
        string str;
        str = $sformatf("Raw transaction '%s': 0x%0x\n", get_name(), this.data);
        return str;
    endfunction

    // Compare transaction against another
    // [[ implements compare virtual method of std_verif_pkg::transaction ]]
    function automatic bit compare(input raw_transaction#(DATA_T) t2, output string msg);
        if (t2.data == this.data) begin
            msg = "Raw transactions match.";
            return 1;
        end else begin
            msg = $sformatf("Raw data mismatch. A: 0x%0x, B: 0x%0x", this.data, t2.data);
            return 0;
        end
    endfunction

endclass : raw_transaction
