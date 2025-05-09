# SaR (Segmentation and Reassembly)

This library contains RTL components and verification infrastructure for use in building
applications supporting segmentation and reassembly of data frames into/from data packets.

## Unit Tests

This library contains unit tests implemented using the open-source SVUnit test
framework (https://github.com/svunit/svunit).

SVUnit is managed within the repository as a submodule and no separate installation
or setup is required.

### Vivado Simulator Support

In addition, this library contains Makefiles that support running the unit
tests using Xilinx's Vivado Simulator. Vivado is not supported natively by
SVUnit so the 'runSVUnit' script cannot be used directly. To execute the unit
tests using the Vivado simulator:

1. Configure Vivado. For example:
```
source ${XILINX_VIVADO}/settings64.sh
```

2. Execute appropriate Makefile

    Running make in one of the test directories (i.e. tests/\[testbench_name\]/) executes
    the unit tests contained within that testbench.

    ```
    make all
    ```

    Running make at the root of the library or in the tests/regression directory
    executes all of the testcases contained in all of the testbenches.

    Waves (Vivado *.wdb format)
    can be logged by passing 'waves=ON' to the make command. Example:
    ```
    make all waves=ON
    ```
