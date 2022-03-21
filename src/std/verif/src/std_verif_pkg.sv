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

package std_verif_pkg;

    // Base classes
    `include "base.svh"
    `include "transaction.svh"
    `include "component.svh"
    `include "agent.svh"
    `include "driver.svh"
    `include "monitor.svh"
    `include "model.svh"
    `include "predictor.svh"
    `include "scoreboard.svh"
    `include "env.svh"


    // Basic implementation classes
    `include "raw_transaction.svh"
    `include "raw_driver.svh"
    `include "raw_monitor.svh"
    `include "raw_model.svh"
    `include "raw_predictor.svh"
    `include "raw_scoreboard.svh"

    `include "component_env.svh"
    `include "component_ctrl_env.svh"

    `include "wire_model.svh"
    `include "wire_env.svh"

    `include "event_scoreboard.svh"
    `include "table_scoreboard.svh"

    // Typedefs
    typedef enum {
        TX_MODE_SEND,
        TX_MODE_PUSH,
        TX_MODE_PUSH_WHEN_READY
    } tx_mode_t;

    typedef enum {
        RX_MODE_RECEIVE,
        RX_MODE_PULL,
        RX_MODE_ACK,
        RX_MODE_FETCH,
        RX_MODE_ACK_FETCH
    } rx_mode_t;

endpackage : std_verif_pkg

