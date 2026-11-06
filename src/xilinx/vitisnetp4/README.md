# Xilinx VitisNetP4

Build and verification helpers for AMD/Xilinx VitisNetP4 IP generated from
P4 programs. The library connects IP generation to the shared component
build flow and provides a DPI-C agent for control-plane initialization,
table programming, and counter/register access.

## Contents

| Component or directory | Description |
|------------------------|-------------|
| `xilinx.vitisnetp4.dpi` | Build-output copy of the vendor DPI package, including the reset-context indexing patch |
| `xilinx.vitisnetp4.example` | Generated default IP example and CLI parsing helpers |
| `xilinx.vitisnetp4.verif` | Verification package containing `xilinx_vitisnetp4_agent` |
| `xilinx.vitisnetp4.forward.ip` | IP generated from the vendor's forwarding P4 example |
| `forward/tests/` | SVUnit control-plane integration suite |
| `standalone/` | Separate Vivado/xsim demonstration with a local P4 program and extern model |

The managed components use the configured Vivado installation's VitisNetP4
sources, generated packages, simulation libraries, and DPI shared library.
The verification agent also uses [`std.verif`](../../std/verif/README.md).

## IP build integration

[`vivado_vitisnetp4.mk`](../../../scripts/Makefiles/vivado_vitisnetp4.mk)
extends the shared Vivado IP management rules. A component Makefile supplies:

| Variable | Purpose |
|----------|---------|
| `VITISNETP4_IP_NAME` | Generated IP module name |
| `P4_FILE` | P4 program used to configure the IP |
| `P4_OPTS` | Additional Vivado IP configuration properties |

The [component template](../../../scripts/Makefiles/templates/component_ip_vitisnetp4.mk)
and [`forward/ip/Makefile`](forward/ip/Makefile) show the integration.
Consumers declare the IP component as a dependency in the usual component
build flow.

The managed targets create/update the IP, generate simulation products,
prepare synthesis sources, and export software drivers. For example, run
from this directory:

```sh
# Create/update the forwarding IP
make -C forward/ip/ ip

# Generate and compile its simulation products and DPI driver
make -C forward/ip/ compile

# Export and build its software driver
make -C forward/ip/ driver
```

Generated files belong in the component's build output directory. The
shared rules select include paths and vendor library versions using the
configured Vivado version. IP generation and use require the corresponding
vendor installation and licenses.

## DPI package and example helpers

`dpi/` compiles a copy of `vitis_net_p4_dpi_pkg.sv` into the component's build
output. Its Makefile patches context-index accumulation in the vendor
reset routine before compiling that copy.

`example/` generates the vendor's default P4 example design and exposes
its CLI command parser through `xilinx_vitisnetp4_example_pkg`. The helper
package supplies the command types and parsing functions used by the
verification agent. The forwarding IP is generated separately from the
vendor's `forward.p4` program. The example component's preparation target
generates its headers and IP simulation sources before exporting the source
and include manifests consumed by downstream builds.

## Verification agent and AXI4-Lite callbacks

`xilinx_vitisnetp4_verif_pkg::xilinx_vitisnetp4_agent` wraps the vendor DPI
control handle. Construct it with an object name, the hierarchy path of
the module exporting the AXI4-Lite callbacks, and the generated IP's
`XilVitisNetP4Config` value.

The callback module exports these DPI-C tasks:

```systemverilog
task axi_lite_wr(input int address, input int data);
task axi_lite_rd(input int address, inout int data);
```

They perform AXI4-Lite register transactions for the DPI driver. The
forwarding testbench provides implementations with independent address/data
write handshakes and read/write response checks. Its hierarchy path is
captured at module scope for the DPI binding.

| Agent method | Capability |
|--------------|------------|
| `init()` | Initialize the vendor driver and bind its register callbacks |
| `reset_tables()` | Reset the generated IP's table/register state through the driver |
| `table_init_from_file(filename)` | Reset state, parse CLI commands, and execute table/counter/register operations |
| `terminate()` | Invoke the vendor driver's shutdown helper |
| `destroy()` | Release driver contexts and the DPI environment during component teardown |

The CLI helper accepts a filename stem or a `.txt` filename. Supported
commands include table add/modify/delete/clear, counter and register
reads/writes/resets, and reset of the complete driver-managed state.
`set_debug_level()` controls the agent's diagnostic detail; the vendor
library can also emit its own messages.

## Standalone demonstration

`standalone/` has its own Makefile, IP-creation Tcl, simulation Tcl, and
local driver/string packages. Its P4 program parses Ethernet headers,
contains a destination-address forwarding table, and calls a user extern.
`extern_model` supplies a pipelined valid response and constant result for
that extern.

The standalone test drives a sample packet and prints transmitted and
received data. Its `add_rules()` task is a placeholder. This is a separate
demonstration rather than the SVUnit forwarding regression, and its
Makefile maintains independent tool-version-specific source and library
lists. The managed regression results below do not validate this flow.

## Verification and simulator support

The SVUnit forwarding suite checks generated-IP reset, DPI driver
initialization, table reset, and table programming from CLI commands.
The supplied command file programs IPv4 and IPv6 forwarding entries.
The packet stream remains idle, so this suite does not verify packet
forwarding, lookup results, throughput, or datapath backpressure.

The suite passes with Vivado xsim 2025.2. Run from this directory:

```sh
# Individual testbench
make -C forward/tests/vitisnetp4_forward/

# Forwarding regression
make -C forward/tests/regression/

# Use another CLI command file
make -C forward/tests/regression/ CLI_COMMANDS_FILE=/path/to/commands.txt
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.

Use xsim for the current VitisNetP4 simulation flow. As of Verilator 5.054,
there are two independent limitations:

- The generated vendor RTL contains encrypted sections that Verilator skips,
  leaving module definitions unavailable. The post-synthesis functional
  netlist export is also encrypted; `write_verilog -mode funcsim` does not
  provide an unencrypted primitive model for this IP.
- The exported AXI4-Lite callbacks wait for clock edges, and Verilator rejects
  timing controls inside DPI-exported tasks. DPI-C itself is supported; this
  restriction affects the blocking register callbacks used by the vendor
  driver integration.

A Verilator simulation would require a usable IP model and a different
callback integration. The source/include manifest preparation does not
remove these limitations.
