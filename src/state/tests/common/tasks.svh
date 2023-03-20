// ============================================================================
// Common tasks
// 
// Represents listing of common tasks useful for interacting with state
// components.
//
// Can `include into _unit_test modules.
//
// This is a temporary measure to avoid unnecessary duplication of test code
// until this functionality is fully supported in a common testbench environment.
// ============================================================================

task _wait(input int num_cycles);
    update_if._wait(num_cycles);
endtask

task enable(input ID_T id);
    DUMMY_T __state_unused = 0;
    set(id, __state_unused);
endtask

task _disable(input ID_T id, output bit prev_valid);
    DUMMY_T __prev_state_unused = 0;
    bit error, timeout;
    ctrl_agent.unset(id, prev_valid, __prev_state_unused, error, timeout);
    `FAIL_IF_LOG(
        error,
        $sformatf(
            "Error detected while disabling ID 0x%0x.",
            id
        )
    );
    `FAIL_IF_LOG(
        timeout,
        $sformatf(
            "Timeout detected while disabling ID 0x%0x.",
            id
        )
    );

endtask

task send(input ID_T id, input UPDATE_T update, input bit init=1'b0);
    update_if.send(id, update, init);
endtask

task receive(output STATE_T state);
    bit __timeout;
    update_if.receive(state, __timeout);
endtask

task set(input ID_T id, input STATE_T state);
    automatic logic __dummy = 1'b0;
    bit error;
    bit timeout;
    ctrl_agent.set(id, state, error, timeout);
    `FAIL_IF_LOG(
        error,
        $sformatf(
            "Error detected while setting state for ID 0x%0x.",
            id
        )
    );
    `FAIL_IF_LOG(
        timeout,
        $sformatf(
            "Timeout detected while setting state for ID 0x%0x.",
            id
        )
    );
endtask

task clear(input ID_T id, output STATE_T prev_state);
    logic __dummy;
    bit error;
    bit timeout;
    ctrl_agent.unset(id, __dummy, prev_state, error, timeout);
    `FAIL_IF_LOG(
        error,
        $sformatf(
            "Error detected while clearing state for ID 0x%0x.",
            id
        )
    );
    `FAIL_IF_LOG(
        timeout,
        $sformatf(
            "Timeout detected while clearing state for ID 0x%0x.",
            id
        )
    );
endtask

task get(input ID_T id, output STATE_T state);
    logic __dummy;
    bit error;
    bit timeout;
    ctrl_agent.get(id, __dummy, state, error, timeout);
    `FAIL_IF_LOG(
        error,
        $sformatf(
            "Error detected while retrieving state for ID 0x%0x.",
            id
        )
    );
    `FAIL_IF_LOG(
        timeout,
        $sformatf(
            "Timeout detected while retrieving state for ID 0x%0x.",
            id
        )
    );
endtask

task get_valid(input ID_T id, output bit valid);
    logic __dummy;
    bit error;
    bit timeout;
    ctrl_agent.get(id, valid, __dummy, error, timeout);
    `FAIL_IF_LOG(
        error,
        $sformatf(
            "Error detected while retrieving valid for ID 0x%0x.",
            id
        )
    );
    `FAIL_IF_LOG(
        timeout,
        $sformatf(
            "Timeout detected while retrieving valid for ID 0x%0x.",
            id
        )
    );
endtask

task clear_all();
    bit error;
    bit timeout;
    ctrl_agent.clear_all(error, timeout);
    `FAIL_IF_LOG(
        error,
        "Error detected while performing RESET operation."
    );
    `FAIL_IF_LOG(
        timeout,
        "Timeout detected while performing RESET operation."
    );
endtask

