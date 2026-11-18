    task query(
            input KEY_T key,
            output bit valid,
            output VALUE_T value
        );
        bit error;
        bit timeout;
        app_rd_agent.query(key, valid, value, error, timeout);
        `FAIL_IF_LOG(error, $sformatf("Error while querying entry associated with key 0x%0x.", key));
        `FAIL_IF_LOG(timeout, $sformatf("Timeout while querying entry associated with key 0x%0x.", key));
    endtask

    task update(
            input KEY_T key,
            input bit valid,
            input VALUE_T value
        );
        bit error;
        bit timeout;
        app_wr_agent.update(key, valid, value, error, timeout);
        `FAIL_IF_LOG(error, $sformatf("Error while updating entry associated with key 0x%0x.", key));
        `FAIL_IF_LOG(timeout, $sformatf("Timeout while updating entry associated with key 0x%0x.", key));
    endtask

    task post_update(
            input KEY_T key,
            input bit valid,
            input VALUE_T value
        );
        bit timeout;
        app_wr_agent.post_update(key, valid, value, timeout);
        `FAIL_IF_LOG(timeout, $sformatf("Timeout while posting update to entry associated with key 0x%0x.", key));
    endtask

