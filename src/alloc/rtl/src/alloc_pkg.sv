package alloc_pkg;

    // Typedefs
    class alloc #(parameter int SIZE = 1, parameter int PTR_WID = 1, parameter int META_WID = 1);

        // Derived parameters
        localparam int SIZE_WID = $clog2(SIZE);

        typedef struct packed {
            logic                sof;
            logic                eof;
            logic [SIZE_WID-1:0] size;
            logic                err;
            logic [META_WID-1:0] meta;
            logic [PTR_WID-1:0]  nxt_ptr;
        } desc_t;
    endclass : alloc

endpackage : alloc_pkg
