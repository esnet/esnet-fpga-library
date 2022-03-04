# CRC

This library contains hardware implementations of CRC (Cyclic-Redundancy Check) operations.

## Unit Tests

This library contains unit tests implemented using the open-source SVUnit test
framework. SVUnit is available on Github at https://github.com/tudortimi/svunit.
Instructions for installing and configuring the framework are provided.

The unit tests can be executed using SVUnit's runSVUnit script in conjunction
with any of the supported simulators. See 'Run the unit tests' section
of the SVUnit README.

### Vivado Simulator Support

In addition, this library contains Makefiles that support running the unit
tests using Xilinx's Vivado Simulator. Vivado is not one of the simulators
supported by SVUnit so the 'runSVUnit' script cannot be used directly. To
execute the unit tests using the Vivado simulator:

1. Configure Vivado. For example:
```
source ${XILINX_VIVADO}/settings64.sh
```
2. Configure SVUnit by sourcing setup script. Note that the setup script must be
sourced from within SVUnit install directory, as described in the SVUnit README.
For example:
```
cd [path-to-svunit]
source Setup.bsh
```

3. Execute appropriate Makefile

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
