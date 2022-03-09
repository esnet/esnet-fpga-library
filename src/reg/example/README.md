# Placeholder - More details to follow...

## Register Infrastructure

Register infrastructure makes use of the ESnet regio tool. Address decoders and register
blocks are described in yaml specifications.  These yaml specifications are then compiled to
auto-generate associated definitions, as well as logic and verification components (using
standardized templates).

### Adding a new register block to the design

1. Create a yaml specification describing the block's registers.
2. Connect the yaml to a parent yaml.
3. Run regio via the make system to produce RTL.
4. Instantiate the registers in the block.
5. Connect the AXI-L bus from the parent to the AXI-L for the block.

### Simulation

* Use agent functions in the testbench to read/write registers.
* Use address-based function calls as an alternateive to named agent-based calls.


