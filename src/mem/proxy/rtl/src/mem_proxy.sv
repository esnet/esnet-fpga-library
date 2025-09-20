module mem_proxy
    import mem_pkg::*;
#(
    parameter access_t ACCESS_TYPE = ACCESS_UNSPECIFIED,  // See mem_pkg for supported values
    parameter mem_type_t MEM_TYPE = MEM_TYPE_UNSPECIFIED, // See mem_pkg for supported values
    parameter int TIMEOUT_CYCLES = 1000,
    parameter int BIGENDIAN = 0
)(
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    output logic               init_done,

    // AXI4-Lite control interface
    axi4l_intf.peripheral      axil_if,

    // Memory interface
    mem_intf.controller        mem_if
);
    // -----------------------------
    // Imports
    // -----------------------------
    import mem_proxy_reg_pkg::*;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int     ADDR_WID = mem_if.ADDR_WID;
    localparam longint MEM_DEPTH = 2**ADDR_WID;

    localparam int  DATA_WID = mem_if.DATA_WID;
    localparam bit  DATA_WID_IS_N_BYTES = (DATA_WID % 8 == 0);
    localparam int  DATA_BYTES = DATA_WID % 8 == 0 ? DATA_WID / 8 : DATA_WID / 8 + 1;

    localparam longint MEM_SIZE = MEM_DEPTH * DATA_BYTES;

    // Determine burst parameters (in bytes)
    localparam int BURST_LEN_MAX = DATA_WID_IS_N_BYTES ? mem_proxy_reg_pkg::COUNT_WR_DATA * 4 / DATA_BYTES : 1;
    localparam int BURST_SIZE_MIN = DATA_BYTES;
    localparam int BURST_SIZE_MAX = DATA_BYTES * BURST_LEN_MAX;
    localparam int BURST_LEN_WID = $clog2(BURST_LEN_MAX+1);
    localparam int BURST_SIZE_WID = $clog2(BURST_SIZE_MAX+1);

    // Determine depth of write/read data arrays
    localparam int DATA_REGS  = BURST_SIZE_MAX % 4 == 0 ? BURST_SIZE_MAX / 4 : BURST_SIZE_MAX / 4 + 1;

    localparam int INIT_DEBOUNCE_CYCLES = 8;
    localparam int TIMEOUT_WID = TIMEOUT_CYCLES > INIT_DEBOUNCE_CYCLES ? $clog2(TIMEOUT_CYCLES + 1) : $clog2(INIT_DEBOUNCE_CYCLES + 1);

    // -----------------------------
    // Parameter Validation
    // -----------------------------
    initial begin
        // Enforce access size of N*8 bits when BURST_LEN > 1, i.e. when multi-cycle accesses are possible
        if (BURST_LEN_MAX > 1) std_pkg::param_check(DATA_WID_IS_N_BYTES, 1, "DATA_WID_IS_N_BYTES");
    end

    // -----------------------------
    // Functions
    // -----------------------------
    // -- RTL to regmap translation (memory type)
    function automatic fld_info_mem_type_t getRegFromType(input mem_type_t mem_type);
        case (mem_type)
            MEM_TYPE_SRAM : return INFO_MEM_TYPE_SRAM;
            MEM_TYPE_DDR  : return INFO_MEM_TYPE_DDR;
            MEM_TYPE_HBM  : return INFO_MEM_TYPE_HBM;
            default       : return INFO_MEM_TYPE_UNSPECIFIED;
        endcase
    endfunction
    // -- RTL to regmap translation (access type)
    function automatic fld_info_access_t getRegFromAccess(input access_t access);
        case (access)
            ACCESS_READ_WRITE : return INFO_ACCESS_READ_WRITE;
            ACCESS_READ_ONLY  : return INFO_ACCESS_READ_ONLY;
            default           : return INFO_ACCESS_UNSPECIFIED;
        endcase
    endfunction
    // -- Regmap to RTL translation (command)
    function automatic command_t getCommandFromReg(input fld_command_code_t command_code);
        case (command_code)
            COMMAND_CODE_READ        : return COMMAND_READ;
            COMMAND_CODE_WRITE       : return COMMAND_WRITE;
            COMMAND_CODE_CLEAR       : return COMMAND_CLEAR;
            default                  : return COMMAND_NOP;
        endcase
    endfunction

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef logic [3:0][7:0] reg_t;
    
    typedef enum logic [3:0] {
        RESET          = 0,
        INIT_DEBOUNCE  = 1,
        INIT_PENDING   = 2,
        IDLE           = 3,
        READ_REQ       = 4,
        READ_PENDING   = 5,
        WRITE_REQ      = 6,
        WRITE_PENDING  = 7,
        CLEAR_REQ      = 8,
        CLEAR_DEBOUNCE = 9,
        CLEAR_PENDING  = 10,
        DONE           = 11,
        ERROR          = 12,
        TIMEOUT        = 13
    } state_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic      local_srst;

    fld_status_code_t status_code;
    logic      status_done;
    logic      status_error;
    logic      status_timeout;
    logic [BURST_SIZE_WID-1:0] status_burst_size;

    logic      status_rd_ack;

    logic      command_evt;

    logic      req;
    logic      rdy;

    logic                mem_init;
    logic                mem_wr_req;
    logic                mem_rd_req;
    logic [ADDR_WID-1:0] mem_addr;
    logic [DATA_WID-1:0] mem_wr_data;

    command_t            command;
    logic [ADDR_WID-1:0] addr;

    logic [0:BURST_LEN_MAX-1][DATA_BYTES-1:0][7:0] wr_data_in;
    logic [0:BURST_LEN_MAX-1][DATA_BYTES-1:0][7:0] wr_data;

    logic [0:BURST_LEN_MAX-1][DATA_BYTES-1:0][7:0] rd_data;

    state_t    state;
    state_t    nxt_state;

    logic      done;
    logic      error;
    logic      timeout;

    logic [TIMEOUT_WID-1:0] timer;
    logic                   reset_timer;
    logic                   inc_timer;

    logic [BURST_LEN_WID-1:0] burst_len;
    logic [BURST_LEN_WID-1:0] word;
    logic                     reset_word;
    logic                     inc_word;

    // -----------------------------
    // Local interfaces
    // -----------------------------
    mem_proxy_reg_intf reg_if ();

    axi4l_intf #() axil_if__clk ();

    // ----------------------------------------
    // Memory proxy register block
    // ----------------------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    // Registers
    mem_proxy_reg_blk i_mem_proxy_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    // Soft reset
    initial local_srst = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset) local_srst <= 1'b1;
        else                              local_srst <= 1'b0;
    end

    // Monitor
    assign reg_if.monitor_nxt_v = 1'b1;
    assign reg_if.monitor_nxt.reset_mon = local_srst;
    assign reg_if.monitor_nxt.enable_mon = 1'b1;
    assign reg_if.monitor_nxt.ready_mon = init_done;
    assign reg_if.monitor_nxt.state_mon = fld_monitor_state_mon_t'({'0, state});

    // Assign static INFO register values
    assign reg_if.info_nxt_v = 1'b1;
    assign reg_if.info_nxt.mem_type = getRegFromType(MEM_TYPE);
    assign reg_if.info_nxt.access = getRegFromAccess(ACCESS_TYPE);
    assign reg_if.info_nxt.alignment = DATA_BYTES;

    assign reg_if.info_depth_nxt_v = 1'b1;
    assign reg_if.info_depth_nxt = MEM_DEPTH;

    assign reg_if.info_size_lower_nxt_v = 1'b1;
    assign reg_if.info_size_lower_nxt = MEM_SIZE[31:0];

    assign reg_if.info_size_upper_nxt_v = 1'b1;
    assign reg_if.info_size_upper_nxt = MEM_SIZE[63:32];

    assign reg_if.info_burst_nxt_v = 1'b1;
    assign reg_if.info_burst_nxt.min = BURST_SIZE_MIN;
    assign reg_if.info_burst_nxt.max = BURST_SIZE_MAX;
    assign reg_if.info_burst_nxt.rsvd0 = '0;
    assign reg_if.info_burst_nxt.rsvd1 = '0;

    // Report state machine status to regmap
    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.code  = status_code;
    assign reg_if.status_nxt.done  = status_done;
    assign reg_if.status_nxt.error = status_error;
    assign reg_if.status_nxt.timeout = status_timeout;
    assign reg_if.status_nxt.burst_size = status_burst_size;
    assign reg_if.status_nxt.rsvd = '0;

    // Status read event
    assign status_rd_ack = reg_if.status_rd_evt;

    // Command
    assign command_evt = reg_if.command_wr_evt;

    // Pack write data from registers
    generate
        for (genvar g_reg = 0; g_reg < DATA_REGS; g_reg++) begin : g__wr_data_reg
            reg_t wr_data_reg;
            assign wr_data_reg = reg_if.wr_data[g_reg];
            for (genvar g_reg_byte = 0; g_reg_byte < 4; g_reg_byte++) begin : g__byte
                localparam int byte_idx = (g_reg * 4 + g_reg_byte);
                localparam int word_idx = (g_reg * 4 + g_reg_byte) / DATA_BYTES;
                localparam int word_byte_idx = BIGENDIAN ? DATA_BYTES - (byte_idx % DATA_BYTES) - 1 : byte_idx % DATA_BYTES;
                if (byte_idx < BURST_SIZE_MAX) assign wr_data_in[word_idx][word_byte_idx] = wr_data_reg[g_reg_byte];
                else                           assign wr_data_in[word_idx][word_byte_idx] = 8'h0;
            end : g__byte
        end : g__wr_data_reg
    endgenerate

    // ----------------------------------------
    // Logic
    // ----------------------------------------
    // Latch request
    initial req = 1'b0;
    always @(posedge clk) begin
        if (local_srst)       req <= 1'b0;
        else if (command_evt) req <= 1'b1;
        else if (rdy)         req <= 1'b0;
    end

    // Latch command code
    initial command = COMMAND_NOP;
    always @(posedge clk) begin
        if (command_evt) command <= getCommandFromReg(reg_if.command.code);
    end

    // Latch burst length
    initial burst_len = '0;
    always @(posedge clk) if (command_evt) burst_len <= reg_if.burst.len[BURST_LEN_WID-1:0] > 0 ? reg_if.burst.len[BURST_LEN_WID-1:0] : 1;

    // Latch address
    initial addr = '0;
    always @(posedge clk) if (command_evt) addr <= reg_if.addr;

    // Latch write data
    initial wr_data = '0;
    always @(posedge clk) if (command_evt) wr_data <= wr_data_in;

    // Transaction state machine
    initial state = RESET;
    always @(posedge clk) begin
        if (local_srst) state <= RESET;
        else            state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        mem_wr_req = 1'b0;
        mem_init = 1'b0;
        mem_rd_req = 1'b0;
        reset_timer = 1'b0;
        inc_timer = 1'b0;
        reset_word = 1'b0;
        inc_word = 1'b0;
        rdy = 1'b0;
        done = 1'b0;
        error = 1'b0;
        timeout = 1'b0;
        init_done = 1'b1;
        case (state)
            RESET : begin
                init_done = 1'b0;
                reset_timer = 1'b1;
                mem_init = 1'b1;
                nxt_state = INIT_DEBOUNCE;
            end
            INIT_DEBOUNCE : begin
                init_done = 1'b0;
                inc_timer = 1'b1;
                if (timer == INIT_DEBOUNCE_CYCLES) nxt_state = INIT_PENDING;
            end
            INIT_PENDING : begin
                init_done = 1'b0;
                if (mem_if.rdy) nxt_state = IDLE;
            end
            IDLE : begin
                rdy = 1'b1;
                reset_timer = 1'b1;
                reset_word = 1'b1;
                if (req) begin
                    case (command)
                        COMMAND_READ  : nxt_state = READ_REQ;
                        COMMAND_WRITE : nxt_state = WRITE_REQ;
                        COMMAND_CLEAR : nxt_state = CLEAR_REQ;
                        default       : nxt_state = DONE;
                    endcase
                end
            end
            READ_REQ : begin
                inc_timer = 1'b1;
                mem_rd_req = 1'b1;
                if (mem_if.rdy) nxt_state = READ_PENDING;
            end
            READ_PENDING : begin
                inc_timer = 1'b1;
                if (mem_if.rd_ack) begin
                    inc_word = 1'b1;
                    if (word < burst_len-1) nxt_state = READ_REQ;
                    else                    nxt_state = DONE;
                end else if (timer == TIMEOUT_CYCLES) nxt_state = TIMEOUT;
            end
            WRITE_REQ : begin
                inc_timer = 1'b1;
                mem_wr_req = 1'b1;
                if (mem_if.rdy) nxt_state = WRITE_PENDING;
            end
            WRITE_PENDING : begin
                inc_timer = 1'b1;
                if (mem_if.wr_ack) begin
                    inc_word = 1'b1;
                    if (word < burst_len-1) nxt_state = WRITE_REQ;
                    else                    nxt_state = DONE;
                end else if (timer == TIMEOUT_CYCLES) nxt_state = TIMEOUT;
            end
            CLEAR_REQ : begin
                inc_timer = 1'b1;
                mem_init = 1'b1;
                nxt_state = CLEAR_DEBOUNCE;
            end
            CLEAR_DEBOUNCE : begin
                inc_timer = 1'b1;
                if (timer == INIT_DEBOUNCE_CYCLES) nxt_state = CLEAR_PENDING;
            end
            CLEAR_PENDING : begin
                if (mem_if.rdy) nxt_state = DONE;
            end
            DONE: begin
                done = 1'b1;
                nxt_state = IDLE;
            end
            TIMEOUT : begin
                timeout = 1'b1;
                nxt_state = IDLE;
            end
            default : begin
                error = 1'b1;
                nxt_state = IDLE;
            end
        endcase
    end

    // Burst word count
    initial word = '0;
    always @(posedge clk) begin
        if (reset_word) word <= '0;
        else if (inc_word) word <= word + 1;
    end

    // Timer
    initial timer = '0;
    always @(posedge clk) begin
        if (reset_timer) timer <= '0;
        else if (inc_timer) timer <= timer + 1;
    end

    // Drive write interface
    always_comb begin
        mem_addr = addr + word;
        mem_wr_data = wr_data[word];
    end

    assign mem_if.rst = mem_init;
    assign mem_if.req = mem_wr_req || mem_rd_req;
    assign mem_if.wr = mem_wr_req;
    assign mem_if.addr = mem_addr;
    assign mem_if.wr_data = mem_wr_data;

    // Read response
    // -- Latch each word in burst
    always @(posedge clk) if (mem_if.rd_ack) rd_data[word] <= mem_if.rd_data;
    // -- Unpack read data to registers
    generate
        for (genvar g_reg = 0; g_reg < DATA_REGS; g_reg++) begin : g__rd_data_reg
            reg_t rd_data_reg;
            for (genvar g_reg_byte = 0; g_reg_byte < 4; g_reg_byte++) begin : g__byte
                localparam int byte_idx = g_reg * 4 + g_reg_byte;
                localparam int word_idx = byte_idx / DATA_BYTES;
                localparam int word_byte_idx = BIGENDIAN ? DATA_BYTES - (byte_idx % DATA_BYTES) - 1 : byte_idx % DATA_BYTES;
                if (byte_idx < BURST_SIZE_MAX) assign rd_data_reg[g_reg_byte] = rd_data[word_idx][word_byte_idx];
                else                           assign rd_data_reg[g_reg_byte] = 8'h0;
            end : g__byte
            assign reg_if.rd_data_nxt_v[g_reg] = 1'b1;
            assign reg_if.rd_data_nxt[g_reg] = rd_data_reg;
        end : g__rd_data_reg
        for (genvar g_reg = DATA_REGS; g_reg < COUNT_RD_DATA; g_reg++) begin : g__rd_data_reg__tieoff
            assign reg_if.rd_data_nxt_v[g_reg] = 1'b1;
            assign reg_if.rd_data_nxt[g_reg] = '0;
        end : g__rd_data_reg__tieoff
    endgenerate

    // -- Convert state to status code
    initial status_code = STATUS_CODE_RESET;
    always @(posedge clk) begin
        case (state)
            RESET   : status_code <= STATUS_CODE_RESET;
            IDLE    : status_code <= STATUS_CODE_READY;
            default : status_code <= STATUS_CODE_BUSY;
        endcase
    end

    // -- Maintain `done` flag
    initial status_done = 1'b0;
    always @(posedge clk) begin
        if (local_srst) status_done <= 1'b0;
        else if (done)  status_done <= 1'b1;
        else if (req)   status_done <= 1'b0;
        else if (status_rd_ack && reg_if.status.done) status_done <= 1'b0;
    end

    // -- Maintain `error` flag
    initial status_error = 1'b0;
    always @(posedge clk) begin
        if (local_srst) status_error <= 1'b0;
        else if (error) status_error <= 1'b1;
        else if (req)   status_error <= 1'b0;
        else if (status_rd_ack && reg_if.status.error) status_error <= 1'b0;
    end

    // -- Maintain `timeout` flag
    initial status_timeout = 1'b0;
    always @(posedge clk) begin
        if (local_srst)   status_timeout <= 1'b0;
        else if (timeout) status_timeout <= 1'b1;
        else if (req)     status_timeout <= 1'b0;
        else if (status_rd_ack && reg_if.status.timeout) status_timeout <= 1'b0;
    end

    // -- Maintain burst size status
    always @(posedge clk) begin
        if (local_srst)   status_burst_size <= '0;
        else if (timeout) status_burst_size <= '0;
        else if (done)    status_burst_size <= burst_len * DATA_BYTES;
        else if (req)     status_burst_size <= '0;
    end

endmodule : mem_proxy
