    task clear_all();
        bit error;
        bit timeout;
        agent.clear_all(error, timeout);
        `FAIL_IF_LOG(error, "Error while clearing database.");
        `FAIL_IF_LOG(timeout, "Timeout while clearing database.");
    endtask

    task set(
            input KEY_T key,
            input VALUE_T value
        );
        bit error;
        bit timeout;
        agent.set(key, value, error, timeout);
        `FAIL_IF_LOG(error, $sformatf("Error while setting entry associated with key 0x%0x.", key));
        `FAIL_IF_LOG(timeout, $sformatf("Timeout while setting entry associated with key 0x%0x.", key));
    endtask

    task get(
            input KEY_T key,
            output bit valid,
            output VALUE_T value
        );
        bit error;
        bit timeout;
        agent.get(key, valid, value, error, timeout);
        `FAIL_IF_LOG(error, $sformatf("Error while getting entry associated with key 0x%0x.", key));
        `FAIL_IF_LOG(timeout, $sformatf("Timeout while getting entry associated with key 0x%0x.", key));
    endtask

    task get_next(
            output bit valid,
            output KEY_T key,
            output VALUE_T value
        );
        bit error;
        bit timeout;
        agent.get_next(valid, key, value, error, timeout);
        `FAIL_IF_LOG(error, "Error while getting next entry.");
        `FAIL_IF_LOG(timeout, "Timeout while getting next entry.");
    endtask

    task unset(
            input KEY_T key,
            output bit valid,
            output VALUE_T value
        );
        bit error;
        bit timeout;
        agent.unset(key, valid, value, error, timeout);
        `FAIL_IF_LOG(error, $sformatf("Error while unsetting entry associated with key 0x%0x.", key));
        `FAIL_IF_LOG(timeout, $sformatf("Timeout while unsetting entry associated with key 0x%0x.", key));
    endtask

    task unset_next(
            output bit valid,
            output KEY_T key,
            output VALUE_T value
        );
        bit error;
        bit timeout;
        agent.unset_next(valid, key, value, error, timeout);
        `FAIL_IF_LOG(error, "Error while unsetting next entry.");
        `FAIL_IF_LOG(timeout, "Timeout while unsetting next entry.");
    endtask

    task replace(
            input KEY_T key,
            input VALUE_T value,
            output bit prev_valid,
            output VALUE_T prev_value
        );
        bit error;
        bit timeout;
        agent.replace(key, value, prev_valid, prev_value, error, timeout);
        `FAIL_IF_LOG(error, $sformatf("Error while replacing entry associated with key 0x%0x.", key));
        `FAIL_IF_LOG(timeout, $sformatf("Timeout while replacing entry associated with key 0x%0x.", key));
    endtask
