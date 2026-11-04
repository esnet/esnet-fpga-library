// Simulation harness for the SVUnit-generated runner.
module svunit_verilator_top;
    timeunit 1ns;
    timeprecision 1ps;

    //===================================
    // SVUnit runner
    //===================================
    testrunner runner();

    //===================================
    // Optional wave capture
    //===================================
    initial begin
        if ($test$plusargs("WAVES")) begin
            $dumpfile("waves.fst");
            $dumpvars(0, svunit_verilator_top);
        end
    end

    //===================================
    // Failure reporting
    //===================================
    // SVUnit's generated runner calls $finish even when assertions fail.
    final begin
        if (runner.svunit_tr != null)
            if (runner.svunit_tr.get_results() == svunit_pkg::FAIL)
                $fatal(1, "SVUnit tests failed");
    end
endmodule
