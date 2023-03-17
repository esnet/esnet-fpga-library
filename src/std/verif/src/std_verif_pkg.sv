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
    `include "event_scoreboard.svh"
    `include "table_scoreboard.svh"

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
        RX_MODE_FETCH_VAL,
        RX_MODE_ACK_FETCH
    } rx_mode_t;

endpackage : std_verif_pkg

