# Copyright Notice

ESnet SmartNIC Copyright (c) 2022, The Regents of the University of
California, through Lawrence Berkeley National Laboratory (subject to
receipt of any required approvals from the U.S. Dept. of Energy),
12574861 Canada Inc., Malleable Networks Inc., and Apical Networks, Inc.
All rights reserved.

If you have questions about your rights to use or distribute this software,
please contact Berkeley Lab's Intellectual Property Office at
IPO@lbl.gov.

NOTICE.  This Software was developed under funding from the U.S. Department
of Energy and the U.S. Government consequently retains certain rights.  As
such, the U.S. Government has been granted for itself and others acting on
its behalf a paid-up, nonexclusive, irrevocable, worldwide license in the
Software to reproduce, distribute copies to the public, prepare derivative
works, and perform publicly and display publicly, and to permit others to do so.

# ESnet FPGA library

Reusable SystemVerilog RTL, verification components, and build tooling for
FPGA designs. The library includes streaming and register interfaces,
memories, FIFOs, packet processing, lookup structures, and supporting
synchronization and arithmetic components.

See the [source library index](src/README.md) for component guides and the
[license](LICENSE.md) for distribution terms. The library is provided as
is, without technical support. The developers can be reached at
smartnic@es.net.

## Repository layout

| Path | Contents |
|------|----------|
| `cfg/` | Tool, device, and environment configuration |
| `config.mk`, `paths.mk` | Project paths and shared build resources |
| `scripts/` | Component creation, compilation, simulation, synthesis, and register-generation rules |
| [`src/`](src/README.md) | RTL libraries, verification helpers, tests, and synthesis examples |
| [`tools/`](tools/README.md) | Regio and SVUnit submodules |

Components use dot-separated references such as `axi4l.rtl`, which maps to
`src/axi4l/rtl/`. Compile Makefiles declare dependencies with
`SUBCOMPONENTS`; shared rules collect sources and build products. Generated
register RTL, compiled libraries, and SVUnit runners live in the output
tree, normally `.out/`. Per-run simulator files use `run_<SEED>/` directories
under the test directory.

## Simulation setup

The shared recipes require GNU Make, Perl for SVUnit runner generation,
and standard Unix shell utilities. Initialize the bundled tools before
running tests:

```sh
git submodule update --init --recursive
```

Set up the Vivado release selected by [`cfg/vivado.mk`](cfg/vivado.mk)
(currently 2025.2), including its `settings64.sh` environment. The build
rules use the Vivado environment to identify the output version even when
Verilator is selected. Register-based suites also require the Python
dependencies described in the [Regio setup guide](tools/regio/README.md).
SVUnit is supplied by the submodule; no separate SVUnit installation is
required.

Portable suites support Vivado xsim and Verilator. The Verilator support
changes target version 5.054; older versions have limitations affecting
clocking blocks and parameterized verification classes. For Verilator,
put `verilator` and a working C++ build toolchain on `PATH`. Vendor IP may
need additional Vivado-generated sources, libraries, and licenses.

### Running tests

Run `make` in an individual testbench directory. Use the regression entry
points listed in the library README: many support `make regression` at the
library root, while others have separate test levels or nested
sub-libraries. Those guides also describe coverage and limitations.

```sh
# Individual suite, xsim (the default)
make -C src/arb/tests/arb_rr/ SIM=xsim

# The same suite with Verilator
make -C src/arb/tests/arb_rr/ SIM=verilator

# Library regression with a fixed random seed
make -C src/arb/ regression SIM=verilator SEED=41
```

A completed run prints SVUnit test and suite results. Check the final
`testrunner` status as well as the process exit status; some negative tests
intentionally produce diagnostic messages. Set `SEED=N` to reproduce a
randomized run. The default seed value is zero; the Verilator recipe maps
zero to one because Verilator reserves zero for seed selection.

### Waveforms

Pass `waves=ON` to the same commands to enable capture. Simulations write
waveforms in `run_<SEED>/` beneath the directory where the test runs:

| Simulator | File | Viewer |
|-----------|------|--------|
| xsim | `waves.wdb` | Vivado waveform viewer (`xsim --gui waves.wdb`) |
| Verilator | `waves.fst` | An FST-capable viewer, such as GTKWave (`gtkwave waves.fst`) |

For example:

```sh
make -C src/arb/tests/arb_rr/ SIM=verilator SEED=41 waves=ON
gtkwave src/arb/tests/arb_rr/run_41/waves.fst
```

Wave capture is optional and can substantially increase runtime and disk
usage for large suites.

## Simulation scope

Unit tests verify functional behavior for the configurations described by
each library. They do not establish synthesis resource mapping, timing
closure, metastability behavior, or full compliance with external bus
specifications. Use the supplied build examples and implementation flows
for hardware checks.

[VitisNetP4](src/xilinx/vitisnetp4/README.md#verification-and-simulator-support)
requires xsim in the current flow. Its generated RTL and functional
netlist contain encrypted sections, and its blocking DPI callbacks use
timing controls unsupported by Verilator 5.054. The library guide records
these limitations and the supported test procedure.
