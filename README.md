# ESnet FPGA library

This library contains general-purpose FPGA logic and associated verification suites.

## Register Infrastructure

Register infrastructure makes use of the esnet/ht/regio tool. Address
decoders and register blocks are described in yaml specifications and
associated definitions, logic and verification components are
auto-generated using standardized templates.

### Adding a new register block to the design

1. Create a yaml specification describing the block's registers.
2. Connect the yaml to a parent yaml.
3. Run regio via the make system to produce RTL.
4. Instantiate the registers in the block.
5. Connect the AXI-L bus from the parent to the AXI-L for the block.

### Simulation

* Use agent functions in the testbench to read/write registers.
* Use address-based function calls as an alternateive to named agent-based calls.
