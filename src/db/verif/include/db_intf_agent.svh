// Application-side access to a database read or write interface.
class db_intf_agent #(
    parameter type KEY_T = bit[15:0],
    parameter type VALUE_T = bit[31:0]
) extends std_verif_pkg::agent;

    // Interface binding
    localparam int KEY_WID = $bits(KEY_T);
    localparam int VALUE_WID = $bits(VALUE_T);
    virtual db_intf #(KEY_WID, VALUE_WID) db_vif;

    function new(input string name="db_intf_agent");
        super.new(name);
        this.db_vif = null;
    endfunction

    // Clock and idle control
    virtual protected task _idle();
        db_vif.cb.req <= 1'b0;
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(db_vif.cb);
    endtask

    task wait_ready(output bit timeout, input int TIMEOUT=32);
        int cycles = 0;
        timeout = 0;
        while (!db_vif.cb.rdy) begin
            @(db_vif.cb);
            cycles++;
            if (TIMEOUT > 0 && cycles >= TIMEOUT) begin
                timeout = 1;
                return;
            end
        end
    endtask

    // Raw request/response helpers (no timeout)
    task send(input KEY_T key);
        db_vif.cb.req <= 1'b1;
        db_vif.cb.key <= key;
        db_vif.cb.next <= 1'b0;
        @(db_vif.cb iff (db_vif.cb.mon_req && db_vif.cb.rdy));
        db_vif.cb.req <= 1'b0;
    endtask

    task wait_ack(output bit error);
        @(db_vif.cb iff (db_vif.cb.ack));
        error = db_vif.cb.error;
    endtask

    task receive(output bit valid, output VALUE_T value, output bit error);
        wait_ack(error);
        valid = db_vif.cb.valid;
        value = db_vif.cb.value;
    endtask

    // Bounded transfers: one cycle budget covers both handshake phases.
    // Poll the sampled clocking-block inputs without spawning timeout threads.
    local task _transfer(
            input KEY_T key,
            input bit write_request,
            input bit write_valid,
            input VALUE_T write_value,
            input bit posted,
            output bit valid,
            output VALUE_T value,
            output bit error,
            output bit timeout,
            input int TIMEOUT
        );
        int cycles = 0;
        valid = 0;
        value = '0;
        error = 0;
        timeout = 0;
        db_vif.cb.key <= key;
        db_vif.cb.next <= 1'b0;
        if (write_request) begin
            db_vif.cb.valid <= write_valid;
            db_vif.cb.value <= write_value;
        end
        db_vif.cb.req <= 1'b1;
        do begin
            @(db_vif.cb);
            cycles++;
            timeout = TIMEOUT > 0 && cycles >= TIMEOUT;
        end while (!timeout && !(db_vif.cb.mon_req && db_vif.cb.rdy));
        db_vif.cb.req <= 1'b0;
        if (timeout || posted) return;
        do begin
            @(db_vif.cb);
            cycles++;
            timeout = TIMEOUT > 0 && cycles >= TIMEOUT;
        end while (!timeout && !db_vif.cb.ack);
        if (timeout) return;
        valid = db_vif.cb.valid;
        value = db_vif.cb.value;
        error = db_vif.cb.error;
    endtask

    task query(
            input KEY_T key, output bit valid, output VALUE_T value,
            output bit error, output bit timeout, input int TIMEOUT=64
        );
        _transfer(key, 0, 0, '0, 0, valid, value, error, timeout, TIMEOUT);
    endtask

    task post_update(
            input KEY_T key, input bit valid, input VALUE_T value,
            output bit timeout, input int TIMEOUT=64
        );
        bit unused_valid, unused_error;
        VALUE_T unused_value;
        _transfer(key, 1, valid, value, 1, unused_valid, unused_value,
                  unused_error, timeout, TIMEOUT);
    endtask

    task update(
            input KEY_T key, input bit valid, input VALUE_T value,
            output bit error, output bit timeout, input int TIMEOUT=64
        );
        bit unused_valid;
        VALUE_T unused_value;
        _transfer(key, 1, valid, value, 0, unused_valid, unused_value,
                  error, timeout, TIMEOUT);
    endtask

endclass : db_intf_agent
