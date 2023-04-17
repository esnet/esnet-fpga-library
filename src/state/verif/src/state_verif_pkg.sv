package state_verif_pkg;

    import state_reg_verif_pkg::*;
    import htable_verif_pkg::*;
    import db_verif_pkg::*;
    import state_pkg::*;

    // Testbench class definitions
    // (declared here to enforce tb_pkg:: namespace for testbench definitions)
    `include "state_aging_core_reg_agent.svh"
    `include "state_allocator_reg_agent.svh"
    `include "state_cache_reg_agent.svh"

    `include "state_req.svh"
    `include "state_resp.svh"
    `include "state_driver.svh"
    `include "state_monitor.svh"

    `include "state_model.svh"
    `include "state_element_model.svh"
    `include "state_vector_model.svh"

endpackage : state_verif_pkg
