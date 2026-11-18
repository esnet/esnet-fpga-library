package std_verif_test_pkg;
    import std_verif_pkg::*;

    //===================================
    // Transaction types
    //===================================
    typedef bit [31:0] word_data_t;
    typedef raw_transaction#(word_data_t) word_t;
    typedef raw_transaction#(byte) byte_t;

    //===================================
    // Lifecycle probe
    //===================================
    class counting_agent extends agent;
        int builds, resets, idles, inits, handled, run_entries;
        mailbox #(int) inbox;

        function new(string name="counting_agent");
            super.new(name);
            inbox = new();
        endfunction
        protected function void _build(); builds++; endfunction
        protected function void _reset(); resets++; handled = 0; endfunction
        protected task _idle(); idles++; endtask
        protected task _init(); inits++; endtask
        protected task _run();
            run_entries++;
            forever begin
                int value;
                inbox.get(value);
                handled++;
            end
        endtask
    endclass

    //===================================
    // Mailbox driver and monitor
    //===================================
    class mailbox_driver extends driver#(word_t);
        mailbox #(word_t) link;
        function new(string name="mailbox_driver"); super.new(name); endfunction
        protected task _idle(); endtask
        protected task _send(input word_t item); link.put(item); endtask
    endclass

    class mailbox_monitor extends monitor#(word_t);
        mailbox #(word_t) link;
        function new(string name="mailbox_monitor"); super.new(name); endfunction
        protected task _idle(); endtask
        protected task _receive(output word_t item); link.get(item); endtask
    endclass

    //===================================
    // Prediction and filtering models
    //===================================
    class xor_predictor extends predictor#(word_t, word_t);
        function new(string name="xor_predictor"); super.new(name); endfunction
        function word_t predict(input word_t item);
            word_t result = new("predicted", item.data ^ 32'h55aa55aa);
            return result;
        endfunction
    endclass

    class raw_xor_predictor extends raw_predictor;
        function new(string name="raw_xor_predictor"); super.new(name); endfunction
        function byte predict_raw(input byte data_in);
            return data_in ^ 8'h5a;
        endfunction
    endclass

    class filtering_model extends raw_model;
        function new(string name="filtering_model"); super.new(name); endfunction
        protected task _process_raw(input byte data_in);
            if (data_in[0]) _drop(byte_t::from_raw(data_in));
            else           _enqueue_raw(data_in + 1);
        endtask
    endclass

    //===================================
    // Non-default payload models
    //===================================
    class wide_echo_model extends raw_model#(word_data_t, word_data_t);
        function new(string name="wide_echo_model"); super.new(name); endfunction
        protected task _process_raw(input word_data_t data_in);
            _enqueue_raw(data_in);
        endtask
    endclass

    typedef bit [63:0] wide_data_t;
    typedef raw_transaction#(wide_data_t) wide_t;

    class wide_predictor extends raw_predictor#(word_data_t, wide_data_t);
        function new(string name="wide_predictor"); super.new(name); endfunction
        function wide_data_t predict_raw(input word_data_t data_in);
            return {32'habcd0123, data_in ^ 32'h55aa55aa};
        endfunction
    endclass

    //===================================
    // Sequence generation and collection
    //===================================
    class expanding_sequencer extends sequencer#(word_t, word_t);
        function new(string name="expanding_sequencer"); super.new(name); endfunction
        protected task _generate(input word_t seq);
            for (int i = 0; i < seq.data; i++) begin
                word_t item = new("element", i);
                _enqueue(item);
            end
        endtask
    endclass

    class pair_collector extends collector#(word_t, word_t);
        bit pending;
        word_data_t first;
        function new(string name="pair_collector"); super.new(name); endfunction
        protected function void _reset();
            super._reset();
            pending = 0;
            first = 0;
        endfunction
        protected task _process(input word_t item);
            if (pending) begin
                word_t result = new("pair", first + item.data);
                _enqueue(result);
                pending = 0;
            end else begin
                first = item.data;
                pending = 1;
            end
        endtask
    endclass

    //===================================
    // Loopback environments
    //===================================
    class loopback_env extends wire_env#(
        word_t, mailbox_driver, mailbox_monitor, raw_scoreboard#(word_data_t)
    );
        function new(string name="loopback_env");
            super.new(name);
            this.driver = new();
            this.monitor = new();
            this.scoreboard = new();
            this.driver.link = new();
            this.monitor.link = this.driver.link;
        endfunction
    endclass

    class controlled_loopback_env extends component_ctrl_env#(
        word_t, word_t, mailbox_driver, mailbox_monitor,
        wire_model#(word_t), raw_scoreboard#(word_data_t), counting_agent
    );
        function new(string name="controlled_loopback_env");
            super.new(name);
            this.driver = new();
            this.monitor = new();
            this.model = new();
            this.scoreboard = new();
            this.agent = new();
            this.driver.link = new();
            this.monitor.link = this.driver.link;
        endfunction
    endclass
endpackage
