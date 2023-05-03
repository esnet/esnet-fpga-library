interface db_status_intf (
    input logic clk,
    input logic srst
);

    // Signals
    logic [31:0] fill;
    logic        empty;
    logic        full;

    // Events
    logic        evt_activate;
    logic        evt_deactivate;

    logic [31:0] cnt_active;
    logic [31:0] cnt_activate;
    logic [31:0] cnt_deactivate;

    modport controller(
        input  fill,
        input  empty,
        input  full,
        input  cnt_active,
        input  cnt_activate,
        input  cnt_deactivate
    );

    modport peripheral(
        output fill,
        output empty,
        output full,
        output evt_activate,
        output evt_deactivate
    );

    // Maintain counters
    initial begin
        cnt_active <= 0;
        cnt_activate <= 0;
        cnt_deactivate <= 0;
    end
    always @(posedge clk) begin
        if (srst) begin
            cnt_active <= 0;
            cnt_activate <= 0;
            cnt_deactivate <= 0;
        end else begin
            if (evt_activate) begin
                cnt_activate <= cnt_activate + 1;
                cnt_active <= cnt_active + 1;
            end
            if (evt_deactivate) begin
                cnt_deactivate <= cnt_deactivate + 1;
                cnt_active <= cnt_active - 1;
            end
        end
    end

endinterface : db_status_intf
