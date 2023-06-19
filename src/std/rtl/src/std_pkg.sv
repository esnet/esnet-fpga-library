package std_pkg;

    function automatic void param_check(input int param_value, input int exp_value, input string param_name, input string msg="");
        assert (param_value == exp_value) else
            $fatal (1, "Parameter check failed for %s. Exp: %0d, Got: %0d.\n%s", param_name, exp_value, param_value, msg);
    endfunction

endpackage : std_pkg

