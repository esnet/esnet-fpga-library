package htable_verif_pkg;

    import htable_reg_verif_pkg::*;

    // Verif class definitions
    // (declared here to enforce htable_verif_pkg:: namespace for verification definitions)
    `include "htable_cuckoo_reg_agent.svh"
    `include "htable_fast_update_reg_agent.svh"

    //===================================
    // Typedefs
    //===================================
    typedef struct {
        bit [63:0] insert_ok;
        bit [63:0] insert_fail;
        bit [63:0] delete_ok;
        bit [63:0] delete_fail;
        bit [31:0] active;
    } stats_t;

endpackage : htable_verif_pkg
