package packet_verif_pkg;
    import packet_reg_verif_pkg::*;
    import mem_proxy_verif_pkg::*;

    `include "packet.svh"
    `include "packet_raw.svh"
    `include "packet_eth.svh"
    `include "packet_driver.svh"
    `include "packet_monitor.svh"
    `include "packet_component_env.svh"
    `include "packet_descriptor.svh"
    `include "packet_descriptor_driver.svh"
    `include "packet_descriptor_monitor.svh"
    `include "packet_write_model.svh"
    `include "packet_enqueue_model.svh"
    `include "packet_intf_driver.svh"
    `include "packet_intf_monitor.svh"
    `include "packet_playback_driver.svh"

endpackage : packet_verif_pkg

