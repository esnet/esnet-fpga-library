// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

interface db_status_intf (
    input logic clk,
    input logic srst
);

    // Signals
    logic [31:0] fill;

    // Events
    logic        evt_activate;
    logic        evt_deactivate;

    logic [31:0] cnt_active;
    logic [31:0] cnt_activate;
    logic [31:0] cnt_deactivate;

    modport controller(
        input  fill,
        input  cnt_active,
        input  cnt_activate,
        input  cnt_deactivate
    );

    modport peripheral(
        output fill,
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
