package bus_verif_pkg;

    `include "bus_driver.svh"
    `include "bus_monitor.svh"

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

endpackage : bus_verif_pkg

