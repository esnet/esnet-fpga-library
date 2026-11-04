// Single-transfer APB register agent. Protocol sequencing lives here;
// the interface supplies signals and the verification clocking block.
class apb_reg_agent #(
    parameter int ADDR_WID = 32,
    parameter int DATA_BYTE_WID = 4
) extends reg_verif_pkg::reg_agent #(ADDR_WID, DATA_BYTE_WID*8);

    //===================================
    // Virtual interface
    //===================================
    virtual apb_intf #(.ADDR_WID(ADDR_WID), .DATA_BYTE_WID(DATA_BYTE_WID)) apb_vif;

    //===================================
    // Construction and idle control
    //===================================
    function new(input string name="apb_reg_agent", input int WR_TIMEOUT=256, input int RD_TIMEOUT=256);
        super.new(name);
        set_wr_timeout(WR_TIMEOUT);
        set_rd_timeout(RD_TIMEOUT);
        this.apb_vif = null;
    endfunction

    virtual protected task _idle();
        apb_vif.cb.paddr <= '0;
        apb_vif.cb.pprot <= apb_pkg::PPROT_DEFAULT;
        apb_vif.cb.psel <= 1'b0;
        apb_vif.cb.penable <= 1'b0;
        apb_vif.cb.pwrite <= 1'b0;
        apb_vif.cb.pwdata <= '0;
        apb_vif.cb.pstrb <= '0;
        @(apb_vif.cb);
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(apb_vif.cb);
    endtask

    //===================================
    // APB transfer sequencing and timeout guard
    //===================================
    local task _transfer(
            input bit wr,
            input addr_t addr,
            input data_t wr_data,
            input bit [DATA_BYTE_WID-1:0] strb,
            output data_t rd_data,
            output bit error
        );
        apb_vif.cb.psel <= 1'b1;
        apb_vif.cb.penable <= 1'b0;
        apb_vif.cb.paddr <= addr;
        apb_vif.cb.pprot <= apb_pkg::PPROT_DEFAULT;
        apb_vif.cb.pwrite <= wr;
        apb_vif.cb.pwdata <= wr_data;
        apb_vif.cb.pstrb <= wr ? strb : '0;
        @(apb_vif.cb);
        apb_vif.cb.penable <= 1'b1;
        @(apb_vif.cb iff (apb_vif.cb.mon_psel && apb_vif.cb.mon_penable && apb_vif.cb.pready));
        rd_data = apb_vif.cb.prdata;
        error = apb_vif.cb.pslverr;
        apb_vif.cb.psel <= 1'b0;
        apb_vif.cb.penable <= 1'b0;
    endtask

    local task _transact(
            input bit wr,
            input addr_t addr,
            input data_t wr_data,
            input bit [DATA_BYTE_WID-1:0] strb,
            output data_t rd_data,
            output bit error,
            output bit timeout,
            input int timeout_cycles
        );
        data_t result = '0;
        bit result_error = 1'b0;
        bit timed_out = 1'b0;
        fork
            begin
                fork
                    _transfer(wr, addr, wr_data, strb, result, result_error);
                    begin
                        if (timeout_cycles > 0) begin
                            wait_n(timeout_cycles);
                            timed_out = 1'b1;
                        end else forever wait_n(1);
                    end
                join_any
                disable fork;
            end
        join
        if (timed_out) _idle();
        rd_data = result;
        error = result_error;
        timeout = timed_out;
    endtask

    //===================================
    // Explicit-strobe transaction API
    //===================================
    task write(
            input addr_t addr,
            input data_t data,
            input bit [DATA_BYTE_WID-1:0] strb,
            output bit error,
            output bit timeout,
            input int WR_TIMEOUT=256
        );
        data_t unused_data;
        _transact(1'b1, addr, data, strb, unused_data, error, timeout, WR_TIMEOUT);
    endtask

    task read(
            input addr_t addr,
            output data_t data,
            output bit error,
            output bit timeout,
            input int RD_TIMEOUT=256
        );
        _transact(1'b0, addr, '0, '0, data, error, timeout, RD_TIMEOUT);
    endtask

    //===================================
    // Register-agent API
    //===================================
    virtual protected task _write(input addr_t addr, input data_t data, output bit error, output bit timeout, output string msg="");
        write(addr, data, '1, error, timeout, get_wr_timeout());
        msg = $sformatf("APB write to 0x%0x (error=%0b, timeout=%0b).", addr, error, timeout);
    endtask

    virtual protected task _read(input addr_t addr, output data_t data, output bit error, output bit timeout, output string msg="");
        read(addr, data, error, timeout, get_rd_timeout());
        msg = $sformatf("APB read from 0x%0x (error=%0b, timeout=%0b).", addr, error, timeout);
    endtask

    virtual protected task _write_byte(input addr_t addr, input byte data, output bit error, output bit timeout, output string msg="");
        addr_t aligned_addr = (addr / DATA_BYTE_WID) * DATA_BYTE_WID;
        int byte_pos = int'(addr % DATA_BYTE_WID);
        data_t shifted_data = '0;
        bit [DATA_BYTE_WID-1:0] strb = '0;
        shifted_data[byte_pos*8 +: 8] = data;
        strb[byte_pos] = 1'b1;
        write(aligned_addr, shifted_data, strb, error, timeout, get_wr_timeout());
        msg = $sformatf("APB byte write to 0x%0x (error=%0b, timeout=%0b).", addr, error, timeout);
    endtask

    virtual protected task _read_byte(input addr_t addr, output byte data, output bit error, output bit timeout, output string msg="");
        addr_t aligned_addr = (addr / DATA_BYTE_WID) * DATA_BYTE_WID;
        int byte_pos = int'(addr % DATA_BYTE_WID);
        data_t read_data;
        read(aligned_addr, read_data, error, timeout, get_rd_timeout());
        data = read_data[byte_pos*8 +: 8];
        msg = $sformatf("APB byte read from 0x%0x (error=%0b, timeout=%0b).", addr, error, timeout);
    endtask

endclass : apb_reg_agent
