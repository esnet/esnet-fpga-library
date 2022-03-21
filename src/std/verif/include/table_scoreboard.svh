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

// Scoreboard class for verification
// - implements 'table-based' scoreboard component, where received and expected
//   results are accumulated in an application-specific method and compared on that basis
class table_scoreboard #(
    parameter type TRANSACTION_T = transaction,
    parameter type KEY_T,
    parameter type RECORD_T
) extends scoreboard#(TRANSACTION_T);

    //===================================
    // Properties
    //===================================
    local RECORD_T __got_table [KEY_T];
    local RECORD_T __exp_table [KEY_T];

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="table_scoreboard");
        super.new(name);
    endfunction

    // Process 'actual' received transaction
    // [[ implements _process_got_transaction() virtual method of scoreboard base class ]]
    protected function automatic TRANSACTION_T _process_got_transaction(input TRANSACTION_T transaction);
        info_msg($sformatf("Processed received transaction:\n%s", transaction.to_string()));
        return transaction;
    endfunction

    // Process 'expected' received transaction
    // [[ implements _process_exp_transaction() virtual method of scoreboard base class ]]
    protected function automatic TRANSACTION_T _process_exp_transaction(input TRANSACTION_T transaction);
        info_msg($sformatf("Processed expected transaction:\n%s", transaction.to_string()));
        return transaction;
    endfunction

    // Start scoreboard
    // [[ implements _run() virtual task of scoreboard base class ]]
    task run();
        forever begin
            TRANSACTION_T got_transaction;
            TRANSACTION_T exp_transaction;
            string compare_msg;
            got_inbox.get(got_transaction);
            got_transaction = process_got_transaction(got_transaction);
            exp_inbox.get(exp_transaction);
            exp_transaction = process_exp_transaction(exp_transaction);
            __processed_cnt += 1;
            if (got_transaction.compare(exp_transaction, compare_msg)) begin
                __match_cnt += 1;
            end else begin
                error_msg(
                    $sformatf(
                        "Mismatch while comparing transactions %s (A) and %s (B).",
                        exp_transaction.get_name(), got_transaction.get_name()
                    )
                );
                error_msg(compare_msg);
                __mismatch_cnt += 1;
            end
        end
    endtask

endclass : table_scoreboard
