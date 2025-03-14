package alloc_pkg;

    // Typedefs
    class alloc #(parameter int SIZE = 1, parameter type PTR_T = logic, parameter type META_T = logic);

        // Derived parameters
        localparam int SIZE_WID = $clog2(SIZE);
        localparam type SIZE_T = logic[SIZE_WID-1:0];

        typedef struct packed {
            logic    sof;
            logic    eof;
            SIZE_T   size;
            logic    err;
            META_T   meta;
            PTR_T    nxt_ptr;
        } desc_t;
    endclass : alloc

endpackage : alloc_pkg
