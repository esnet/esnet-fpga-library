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

class wire_model #(
    parameter type TRANSACTION_T = transaction
) extends model#(TRANSACTION_T, TRANSACTION_T);

    // Constructor
    function new(string name="wire_model");
        super.new(name);
        // Initialize
        this.reset();
    endfunction

    // Called in superclass reset() method to reset state of reference model
    // [[ implements std_verif_pkg::model._reset() virtual method ]]
    function automatic void _reset();
        return;
    endfunction

    // Called in superclass apply() method
    // [[ implements std_verif_pkg::model._apply() virtual method ]]
    function automatic TRANSACTION_OUT_T _apply(input TRANSACTION_IN_T transaction_in);
        return transaction_in;
    endfunction

endclass : wire_model
