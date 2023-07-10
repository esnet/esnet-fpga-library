class db_model #(
    parameter type KEY_T = bit[31:0],
    parameter type VALUE_T = bit[15:0]
) extends std_verif_pkg::predictor#(db_req_transaction#(KEY_T, VALUE_T), db_resp_transaction#(KEY_T, VALUE_T));

    local static const string __CLASS_NAME = "db_verif_pkg::db_model";

    //===================================
    // Properties
    //===================================
    // Database content model
    local VALUE_T __db [KEY_T];
    local const int __CAPACITY;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name = "db_model",
            input int capacity
        );
        super.new(name);
        this.__CAPACITY = capacity;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset model
    // [[ implements std_verif_pkg::model._reset() ]]
    function automatic void _reset();
        trace_msg("_reset()");
        if (__db.size() > 0) __db.delete();
        trace_msg("_reset() Done.");
    endfunction

    function automatic int get_capacity();
        return this.__CAPACITY;
    endfunction

    function automatic int get_occupancy();
        return __db.size();
    endfunction

    function automatic bit full();
        if (get_capacity() > 0) begin
            if (get_occupancy() < get_capacity()) return 1'b0;
            else                                  return 1'b1;
        end else                                  return 1'b0;
    endfunction

    function automatic status_t get(
            input KEY_T key,
            output bit valid,
            output VALUE_T value
        );
        if (__db.exists(key)) begin
            valid = 1'b1;
            value = __db[key];
            return STATUS_OK;
        end else begin
            valid = 1'b0;
            value = '0;
            return STATUS_OK;
        end
    endfunction

    function automatic status_t set(
            input KEY_T key,
            input VALUE_T value
        );
        if (__db.exists(key) || !full()) begin
            __db[key] = value;
            return STATUS_OK;
        end else return STATUS_ERROR;
    endfunction

    function automatic status_t unset(
            input KEY_T key,
            output bit valid,
            output VALUE_T value
        );
        status_t status = get(key, valid, value);
        if (valid) __db.delete(key);
        return status;
    endfunction

    function automatic status_t replace(
            input KEY_T key,
            input VALUE_T new_value,
            output bit valid,
            output VALUE_T prev_value
        );
        status_t status = get(key, valid, prev_value);
        void'(set(key, new_value));
        return status;
    endfunction

    function automatic status_t nop();
        return STATUS_OK;
    endfunction

    protected function automatic TRANSACTION_OUT_T _set(
            input KEY_T key,
            input VALUE_T value
        );
        TRANSACTION_OUT_T transaction_out;
        if (__db.exists(key) || !full()) begin
            __db[key] = value;
            transaction_out = new(.key(key), .status(STATUS_OK));
        end else begin
            transaction_out = new(.key(key), .status(STATUS_ERROR));
        end
        return transaction_out;
    endfunction

    function automatic status_t clear_all();
        trace_msg("clear_all()");
        _reset();
        trace_msg("clear_all() Done.");
        return STATUS_OK;
    endfunction

    protected function automatic TRANSACTION_OUT_T _get(
            input KEY_T key
        );
        TRANSACTION_OUT_T transaction_out;
        if (__db.exists(key)) transaction_out = new(.key(key), .found(1'b1), .value(__db[key]));
        else                  transaction_out = new(.key(key), .found(1'b0));
        return transaction_out;
    endfunction

    protected function automatic TRANSACTION_OUT_T _unset(
            input KEY_T key
        );
        TRANSACTION_OUT_T transaction_out;
        if (__db.exists(key) || !full()) begin
            transaction_out = new(.key(key), .found(1'b1), .value(__db[key]));
            __db.delete(key);
        end else begin
            transaction_out = new(.key(key), .found(1'b0));
        end
        return transaction_out;
    endfunction
    
    // Given input transaction, predict corresponding output transaction
    // [[ implements std_verif_pkg::predictor.predict() ]]
    function automatic TRANSACTION_OUT_T predict(input TRANSACTION_IN_T transaction);
        TRANSACTION_OUT_T transaction_out;
        bit valid;
        VALUE_T value;
        status_t status;
        case (transaction.command)
            COMMAND_GET:     status = get(transaction.key, valid, value);
            COMMAND_SET:     status = set(transaction.key, transaction.value);
            COMMAND_UNSET:   status = unset(transaction.key, valid, value);
            COMMAND_REPLACE: status = replace(transaction.key, transaction.value, valid, value);
            default: begin
                status = STATUS_ERROR;
                error_msg("Command not supported.");
            end
        endcase
        transaction_out = new(
            $sformatf("db_resp_transaction[%0d]", num_input_transactions()),
            transaction.key,
            valid,
            value,
            status
        );
        return transaction_out;
    endfunction

endclass : db_model
