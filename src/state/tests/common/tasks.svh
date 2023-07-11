// ============================================================================
// Common tasks
// 
// Represents listing of common tasks useful for interacting with state
// components.
//
// Can `include into _unit_test modules.
// ============================================================================

task _wait(input int num_cycles);
    env._wait(num_cycles);
endtask

task update_req(input ID_T id, input UPDATE_T update, input bit init=1'b0);
    env.update_vif.update_req(id, update, init);
endtask

task receive(output STATE_T state);
    bit timeout;
    env.update_vif.receive_resp(state, timeout);
    `FAIL_IF_LOG(timeout, "Timeout detected while waiting for update response.");
endtask

task _update(input ID_T id, input UPDATE_T update, output STATE_T state, input bit init=1'b0);
    bit timeout;
    env.update_vif._update(id, update, init, state, timeout);
    `FAIL_IF_LOG(timeout, $sformatf("Timeout detected while updating state for ID 0x%0x.", id));
endtask

task control_update(input ID_T id, input UPDATE_T update, output STATE_T state, input bit init=1'b0);
    bit timeout;
    env.ctrl_vif.control(id, update, init, state, timeout);
    `FAIL_IF_LOG(timeout, $sformatf("Timeout detected while performing control update for ID 0x%0x.", id));
endtask

task _reap(input ID_T id, output STATE_T state);
    bit timeout;
    env.ctrl_vif.reap(id, state, timeout);
    `FAIL_IF_LOG(timeout, $sformatf("Timeout detected while reaping state for ID 0x%0x.", id));
endtask

task set(input ID_T id, input STATE_T state);
    automatic logic __dummy = 1'b0;
    bit error;
    bit timeout;
    env.db_agent.set(id, state, error, timeout);
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
    env.db_agent.unset(id, __dummy, prev_state, error, timeout);
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
    env.db_agent.get(id, __dummy, state, error, timeout);
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

task clear_all();
    bit error;
    bit timeout;
    env.db_agent.clear_all(error, timeout);
    `FAIL_IF_LOG(
        error,
        "Error detected while performing RESET operation."
    );
    `FAIL_IF_LOG(
        timeout,
        "Timeout detected while performing RESET operation."
    );
endtask

function automatic STATE_T get_next_state(input STATE_T prev_state, input UPDATE_T update, input bit init=1'b0);
    return env.model.get_next_state(UPDATE_CTXT_DATAPATH, prev_state, update, init);
endfunction

function automatic STATE_T get_next_state_control(input STATE_T prev_state, input UPDATE_T update, input bit init=1'b0);
    return env.model.get_next_state(UPDATE_CTXT_CONTROL, prev_state, update, init);
endfunction

function automatic STATE_T get_next_state_reap(input STATE_T prev_state, input UPDATE_T update, input bit init=1'b0);
    return env.model.get_next_state(UPDATE_CTXT_REAP, prev_state, update, init);
endfunction

function automatic STATE_T get_return_state(input STATE_T prev_state, input STATE_T next_state);
    return env.model.get_return_state(prev_state, next_state);
endfunction
