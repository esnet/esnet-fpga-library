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

class fifo_core_reg_agent extends fifo_core_reg_blk_agent;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="fifo_ctrl_reg_agent",
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
    endfunction
 
    // Reset agent state
    // [[ implements std_verif_pkg::agent.reset() virtual method ]]
    function automatic void reset();
        // Nothing extra to do
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        soft_reset();
    endtask

    task get_depth(output int depth);
        fifo_core_reg_pkg::reg_info_depth_t reg_info_depth;
        this.read_info_depth(reg_info_depth);
        depth = reg_info_depth;
    endtask

    task is_async(output bit async);
        fifo_core_reg_pkg::reg_info_t reg_info;
        this.read_info(reg_info);
        if (reg_info.fifo_type === fifo_core_reg_pkg::INFO_FIFO_TYPE_ASYNC) async = 1'b1;
        else                                                                async = 1'b0;
    endtask

    task soft_reset();
        fifo_core_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1'b1;
        this.write_control(reg_control);
        reg_control.reset = 1'b0;
        this.write_control(reg_control);
    endtask

endclass : fifo_core_reg_agent
