package math_pkg;

    // ----------------------------------------
    // Constant functions
    // - can be used to calculate parameters
    //   (unsuitable for logic implementation)
    // ----------------------------------------
    function int MAX(input int a, input int b);
        if (a > b) return a;
        else       return b;
    endfunction

    function int MIN(input int a, input int b);
        if (a < b) return a;
        else       return b;
    endfunction

    function int ABS(input int a);
        return MAX(a, -a);
    endfunction

    function int GCD(input int a, input int b);
        int r;
        while (b != 0) begin
            r = b;
            b = a % b;
            a = r;
        end
        return ABS(a);
    endfunction

    function int LCM(input int a, input int b);
        return (a * b / GCD(a,b));
    endfunction

    // ----------------------------------------
    // Vector functions
    // - operations on bit vectors of width WID
    // - suitable for logic implementation
    // ----------------------------------------
    class vec#(parameter int WID=1);

        // Count ones in bit vector
        static function logic[$clog2(WID+1)-1:0] count_ones(input logic[WID-1:0] _vec);
            logic [$clog2(WID+1)-1:0] cnt = 0;
            for (int i = 0; i < WID; i++) begin
                cnt += _vec[i];
            end
            return cnt;
        endfunction

    endclass

endpackage : math_pkg

