package fec_pkg;

    // Typedefs
    typedef enum logic {
        CW_TO_COL = 1'b0,
        COL_TO_CW = 1'b1
    } fec_blk_transpose_mode_t;


    // FEC Lookup Definitions.
    `include "../include/fec_luts.svh"


    // ----- GF Math Functions -----
    function logic [SYM_SIZE-1:0] gf_mul (input logic [SYM_SIZE-1:0] a, b);
        logic [SYM_SIZE-1:0] y, z;

        y = (GF_EXP_LUT[a] + GF_EXP_LUT[b]) % (GF_ORDER-1);

        if ((a==0) || (b==0)) z = '0;
        else                  z = GF_LOG_LUT[y];

        return z;
    endfunction


    function logic [SYM_SIZE-1:0] gf_div (input logic [SYM_SIZE-1:0] a, b);
        logic [SYM_SIZE-1:0] y, z;

        y = (GF_EXP_LUT[a] - GF_EXP_LUT[b]);
        if  (GF_EXP_LUT[a] < GF_EXP_LUT[b]) y = y + (GF_ORDER-1);

        if ((a==0) || (b==0)) z = '0;
        else                  z = GF_LOG_LUT[y];

        return z;
    endfunction


    function logic [SYM_SIZE-1:0] gf_add (input logic [SYM_SIZE-1:0] a, b);
        return a ^ b;
    endfunction


 
    // ----- Polynomial Math Functions -----
    localparam MAX_LEN = RS_N;

    function void poly_scale (
        input  logic [MAX_LEN-1:0][SYM_SIZE-1:0] poly_a,
        input  int                               len,
        input  logic [MAX_LEN-1:0][SYM_SIZE-1:0] scale,

        output logic [MAX_LEN-1:0][SYM_SIZE-1:0] poly_z
    );
        for (int i = 0; i < len; i++) begin
            poly_z[i] = gf_mul(poly_a[i], scale);
        end
    endfunction


    function void poly_add (
        input  logic [MAX_LEN-1:0][SYM_SIZE-1:0] poly_a,
        input  logic [MAX_LEN-1:0][SYM_SIZE-1:0] poly_b,
        input  int                               len,

        output logic [MAX_LEN-1:0][SYM_SIZE-1:0] poly_z
    );
        for (int i = 0; i < len; i++) begin
            poly_z[i] = gf_add(poly_a[i], poly_b[i]);
        end
    endfunction


    function void poly_div(
        input  logic [MAX_LEN-1:0][SYM_SIZE-1:0] poly_a,
        input  int                               poly_a_len,
        input  logic [MAX_LEN-1:0][SYM_SIZE-1:0] poly_b,
        input  int                               poly_b_len,

        output logic [MAX_LEN-1:0][SYM_SIZE-1:0] quot,
        output int                               quot_len,
        output logic [MAX_LEN-1:0][SYM_SIZE-1:0] rem,
        output int                               rem_len
    );
        logic [MAX_LEN-1:0][SYM_SIZE-1:0] pr;     // partial remainder.
        int                               pr_len;
        logic [MAX_LEN-1:0][SYM_SIZE-1:0] pp;     // partial product.
        int                               pp_len;
        logic [MAX_LEN-1:0][SYM_SIZE-1:0] sp;     // scaled product.
        logic [SYM_SIZE-1:0]              scale;
        int                               q_idx;  // quotient index.

        //$display($sformatf("%h %d %h %d", poly_a, poly_a_len, poly_b, poly_b_len));

        for (int i=0; i < poly_a_len; i++)  pr[i] = poly_a[i];  // initialize partial remainder.
        pr_len = poly_a_len;

        for (int i=0; i < poly_b_len; i++)  pp[i] = poly_b[i];  // initialize partial product.
        for (int i=poly_b_len; i < poly_a_len; i++)  pp[i] = 0;
        pp_len = poly_a_len;

        // division loop
        q_idx = 0;
        while (pr_len >= poly_b_len) begin
            scale = gf_div(pr[0], poly_b[0]);  // scale factor = remainder[0] / divisor[0].

            quot[q_idx] = scale; q_idx++;  // store quotient coefficient.

            for (int i=0; i < pp_len; i++)  sp[i] = gf_mul(pp[i], scale);  // scale partial product.
            //poly_scale(pp, pp_len, scale, sp);

            for (int i=0; i < pr_len; i++)  pr[i] = gf_add(pr[i], sp[i]);  // pr = pr-sp.
            //poly_add(pr, sp, pr_len, pr);

            for (int i=0; i < pr_len-1; i++)  pr[i] = pr[i+1];  // shift pr to remove first element.
            pr_len = pr_len-1;

            pp_len = pp_len-1;  // shift pp to remove last element.
        end

        // assign outputs
        for (int i=0; i < pr_len; i++) rem[i] = pr[i];
        rem_len  = pr_len;
        quot_len = q_idx;

        //$display($sformatf("%h %d", rem, rem_len));

    endfunction

endpackage : fec_pkg
