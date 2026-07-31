# ESnet FPGA Library — Project Context

Shared FPGA library providing RTL components, verification infrastructure, and
Makefile-based build/sim tooling used across ESnet SmartNIC projects.

---

## Component System

### Naming and references

Components are identified by **dot-notation refs** that map directly to
filesystem paths under `src/`:

```
axi4l.rtl          →  src/axi4l/rtl/
fifo.rtl           →  src/fifo/rtl/
xilinx.alveo.usplus.rtl  →  src/xilinx/alveo/usplus/rtl/
```

The ref is also used to derive the **compiled library name** by replacing dots
with double-underscores:

```
axi4l.rtl  →  axi4l__rtl
fifo.rtl   →  fifo__rtl
```

### Standard subcomponents

| Suffix | Purpose |
|--------|---------|
| `rtl` | Synthesisable RTL sources |
| `verif` | Verification helpers / BFMs (sim only) |
| `regio.rtl` | Auto-generated RTL from regio register map |
| `regio.verif` | Auto-generated verif helpers from regio |
| `ip` | Vivado managed IP |
| `bd` | Vivado Block Design |
| `build` | Top-level synthesis/implementation project |
| `tests/<name>` | SVUnit test case |

### Directory layout of a typical component

```
src/<component>/
    config.mk          # sets SRC_ROOT, includes scripts
    Makefile           # regression target, includes component_base.mk
    rtl/
        Makefile       # lists SUBCOMPONENTS, SRC_FILES; includes vivado_compile.mk
        src/           # .sv / .v source files (auto-detected)
        include/       # .svh headers (auto-detected)
    verif/
        Makefile
        src/
    tests/
        test_base.mk   # shared deps / options for all tests in this component
        <testname>/
            Makefile   # sets SUBCOMPONENTS (if different from test_base), includes test_base.mk
            <testname>_unit_test.sv
```

Source files in `src/` and headers in `include/` are picked up automatically;
only list files in `SRC_FILES` when they live outside those directories.

### Cross-library references

Use `@<libname>` suffix to reference a component in another library:

```makefile
SUBCOMPONENTS = \
    fifo.rtl@common \    # fifo.rtl from the library named 'common'
    axi4l.rtl            # axi4l.rtl from the local library
```

The `LIBRARIES` variable maps library names to root paths.

---

## Declaring Sources and Dependencies

### Sources (in a compile Makefile)

```makefile
SRC_FILES =           # files outside ./src (usually empty)
INC_DIRS =            # include dirs outside ./include (usually empty)
SRC_LIST_FILES =      # .f file lists (e.g. from IP generators)
```

All `*.sv`/`*.v` in `./src` and `*.svh` in `./include` are auto-detected.
Package files (`*_pkg.sv`) are compiled first, in the order they appear.

### Dependencies

```makefile
SUBCOMPONENTS = \
    bus.rtl \          # project-internal component
    sync.rtl

EXT_LIBS = \
    unisims_ver \      # pre-compiled Vivado library (name only → xsim.ini)
    axi_vip_v1_1_21   # name only; or name=/path/to/lib for proprietary libs
```

`SUBCOMPONENTS` triggers a recursive `make compile` on each dependency before
compiling the current component.  `EXT_LIBS` becomes `-L` flags to `xvlog`/`xelab`.

### sub.libs propagation

After compiling, `$(OBJ_DIR)/sub.libs` is written containing the full `LIBS`
set (SUBCOMPONENT_LIBS + SUBCOMPONENT_SUBLIBS + EXT_LIBS).  Downstream
consumers read this file transitively, so transitive external library
references propagate automatically without re-listing them.

The `SUBCOMPONENTS ?=` idiom in shared `test_base.mk` files allows individual
test Makefiles to **override** the default set by assigning before the include:

```makefile
# test/foo/Makefile — sets before including test_base.mk
SUBCOMPONENTS = \
    mycomp.bd \          # adds BD dependency not in default set
    mycomp.rtl
include ../test_base.mk  # ?= in test_base.mk has no effect now
```

**Important**: if a test needs BD simulation outputs, `<bd_component>` must
appear in SUBCOMPONENTS — it's the only way `axi_vip_*` and other BD-generated
packages reach the `xvlog` compile command.

---

## Key Makefiles

| File | Role |
|------|------|
| `compile_base.mk` | Synthesises `LIBS`, `SUBCOMPONENT_LIBS`, `SUBCOMPONENT_SUBLIBS`; writes `sub.libs` |
| `vivado_compile.mk` | Adds `LIB_REFS`/`DEFINE_REFS`; drives `xvlog` for sim; drives `sources.tcl` for synth |
| `vivado_sim.mk` | `xsim` runtime; chains to `vivado_elab.mk` |
| `vivado_elab.mk` | `xelab` elaboration; chains to `vivado_compile.mk` |
| `svunit.mk` | Runs `buildSVUnit`, applies Vivado-compatibility patch; sets `SRC_LIST_FILES` |
| `vivado_manage_bd.mk` | BD generation/synth via Vivado managed project; must be included **after** the `$(SYNTH_SOURCES_OBJ)` rule |
| `vivado_manage_ip.mk` | Analogous to `vivado_manage_bd.mk` for standalone IP |
| `vivado_build_*.mk` | Top-level impl flows |
| `regio.mk` | Register-map code generation |
| `component_config_base.mk` | Derives `COMPONENT_REF`, `COMPONENT_NAME`, `COMPONENT_OUT_PATH` from CWD |

### vivado_manage_bd.mk include order — critical rule

`vivado_manage_bd.mk` internally includes `vivado_compile.mk`, which defines
`$(SYNTH_SOURCES_OBJ)`.  If a BD Makefile defines its own recipe for
`$(SYNTH_SOURCES_OBJ)` (using `SYNTH_SOURCES_OBJ_RECIPE_DEFINED`), that
definition **must appear before** the include, or the BD's `read_bd` entries
will be silently dropped from the synthesis sources TCL.

---

## Output Directory Structure

All build products land under `$(LIB_OUTPUT_ROOT)`, typically `.out/<BOARD>/<VIVADO_VERSION>/`:

```
.out/<board>/<version>/
    <component/path>/
        lib/                      # compiled sim library
            <component__name>.rlx # sentinel (touched on successful compile)
            sub.libs              # transitive library name list
            compile_sv.sh         # last xvlog command (debug reference)
            compile_sv.log
        synth/
            sources.tcl           # Vivado read_* commands for synthesis
            sv_pkg_srcs.f         # package file list
            sv_srcs.f             # SV source list
            ...
        srcs/
            sv_pkg_srcs.f         # merged (component + subcomponents) lists
            sv_srcs.f
            inc_dirs.f
            ...
```

---

## SVUnit Tests

- Test files must be named `<module>_unit_test.sv` and use `svunit_defines.svh`.
- `svunit.mk` runs `buildSVUnit` to generate the runner, then patches it for
  Vivado xsim compatibility (replaces `\`include` of `svunit_defines.svh` with
  an explicit path).
- The test snapshot top is `<component_name>.testrunner`.
- Run a single test: `make` from the test directory.
- Run all tests in a component: `make regression` from `tests/regression/`.
- `waves=ON` dumps a `.wdb` waveform; `SEED=N` sets the random seed.

---

## Block Designs (BD)

BD components use `vivado_manage_bd.mk`.  Each BD in `BD_LIST` must have a
corresponding `<bd>.tcl` in the source directory.

### BD TCL files — no sourcing at runtime

Do **not** use `source other.tcl` inside a BD TCL file.  The sourced file
becomes an invisible runtime dependency that Make cannot track.  Inline the
content instead.

### BD simulation compile (`_bd_prj_compile`)

BD Makefiles often define a custom `_bd_prj_compile` target that:
1. Rewrites Vivado-generated `vlog.prj` / `vhdl.prj`, substituting
   `xil_defaultlib` with the component library name.
2. Runs `xvlog --prj` / `xvhdl --prj` to compile BD simulation sources.
3. Writes `sub.libs` listing all BD `EXT_LIBS` for downstream consumers.

The VIP packages (`axi_vip_pkg`, `xilinx_aved_mgmt_sc_axi_vip_*_pkg`, etc.)
are compiled into the BD component library via `xil_defaultlib` entries in
`vlog.prj`.  Tests that import these packages must list the BD component in
`SUBCOMPONENTS`.

---

## Verilator Simulation (`SIM=verilator`)

Partial Verilator support is present.  Run any test with
`make SIM=verilator` to use the Verilator backend instead of xsim.

### What works

- `arb` regression passes cleanly under Verilator.
- `sim.mk` dispatches to `verilator.mk` when `SIM=verilator`; xsim is the
  default and is unaffected.
- `svunit_postprocess.sh` runs unconditionally (not xsim-only) and patches
  the SVUnit-generated file list for simulator-agnostic compatibility.

### Known Verilator limitations / required RTL patterns

The following constructs are accepted by xsim/VCS but rejected or mishandled
by Verilator.  RTL or testbench code that uses them will need to be rewritten
before those components can run under Verilator.

#### 1. Parameterized class type access (`pkg::class#(...)::type`)

Verilator cannot resolve a type accessed through a parameterized class
specialisation in a single expression:

```sv
// NOT supported by Verilator:
localparam type DESC_T = alloc_pkg::alloc#(SIZE, PTR_WID, META_WID)::desc_t;
```

**Workaround:** split into two `typedef` steps so Verilator resolves the
class alias first, then the nested type:

```sv
typedef alloc_pkg::alloc#(SIZE, PTR_WID, META_WID) ALLOC_T;
typedef ALLOC_T::desc_t DESC_T;
```

This resolves the parse error but Verilator may still fail to evaluate
`$bits(DESC_T)` or use `DESC_T` in `localparam` initialisers (see #2).

#### 2. `$bits()` / struct aggregate `localparam` on class-derived types

Verilator triggers an internal elaboration error (`V3Simulate.h: No value
found for node`) when a `localparam` is initialised with a struct aggregate
literal (`'{field: val, ...}`) whose fields depend on a type derived from a
parameterised class, or when `$bits()` is called on such a type.

This affects `mem_pkg::spec_t MEM_SPEC = '{ADDR_WID: ..., DATA_WID: DESC_WID,
...}` wherever `DESC_WID` traces back to a parameterised class type.

**Required fix:** compute the width explicitly from the struct field widths
rather than via `$bits(DESC_T)`, and avoid using those values in struct
aggregate `localparam` initialisers.  In some cases passing width parameters
directly to modules rather than computing them locally may be needed.

#### 3. Ports with default values not auto-connected by `.*`

Verilator requires a signal declaration in the testbench for every port
matched by `.*`, even if the RTL port has a default value.  xsim silently
leaves such ports undriven at their default.

**Fix:** declare the signal explicitly in the testbench and initialise it to
the desired value (usually the port's default):

```sv
logic [PTR_WID:0] BUFFERS = 0;  // matches alloc_sg_core port default
```

#### 4. Testbench NBA vs blocking assignment scheduling

Verilator's scheduler is stricter than xsim's about when blocking assignments
in testbenches take effect relative to RTL NBA flushes.  A blocking `req = 0`
immediately after `@(posedge clk)` can cause comb logic to re-evaluate
(clearing `sel`) before `sel_r <= sel` commits, leading to wrong values being
captured.

**Fix:** use non-blocking assignments (`<=`) for testbench stimulus signals,
or use a clocking block with `output #1` skew, so that stimulus changes land
after the NBA flush.

---

## regio (Register Map Generator)

`*.regio.rtl` and `*.regio.verif` components are auto-generated.  The build
system detects them via `is_regio_component` and compiles at the `*.regio`
scope (which runs the generator) before compiling the `rtl`/`verif` leaf.
The source path for regio components resolves to the parent `regio/` directory,
not the `rtl/` or `verif/` subdirectory.
