# Regio SystemVerilog templates

Jinja templates used by the register-generation build to turn Regio YAML
specifications into RTL and verification agents. These templates define
the generated hardware and agent conventions used throughout the library.
Generation uses the ESnet-maintained Regio tool, included as the
[`tools/regio`](../../../tools/regio/) submodule. See its
[README](../../../tools/regio/README.md) for details about the tool,
register-map specifications, and supported code generators.

## Generated artifacts

Names below use the block or decoder's YAML `name` as `<name>`.

| Template | Output | Purpose |
|----------|--------|---------|
| `reg_pkg_sv.j2` | `<name>_reg_pkg.sv` | Register offsets, field and enum types, register types, and initial values |
| `reg_intf_sv.j2` | `<name>_reg_intf.sv` | Typed application interface with update and access-event signals |
| `reg_blk_sv.j2` | `<name>_reg_blk.sv` | AXI4-Lite register block, storage, address decoding, and readback |
| `decoder_pkg_sv.j2` | `<name>_decoder_pkg.sv` | Peripheral address-map specification |
| `decoder_sv.j2` | `<name>_decoder.sv` | AXI4-Lite decoder wrapper with named peripheral ports |
| `reg_blk_agent_svh.j2` | `<name>_reg_blk_agent.svh` | Typed per-register verification methods |

## Register blocks and application interfaces

Generated packages define byte offsets as `OFFSET_<REGISTER>`, with offset
arrays for register arrays. Register types use `reg_<register>_t`; fielded
registers use packed structures with typed fields, including enums where
specified. The package also provides initialization constants and block
size information.

A generated register block exposes `axi4l_intf.peripheral axil_if` and a
generated application interface's `controller` modport. It terminates the
AXI4-Lite bus using `axi4l_reg_peripheral` and instantiates the
[register storage primitives](../README.md). Application logic connects
to the generated interface's `peripheral` modport.

| YAML access | Application behavior |
|-------------|----------------------|
| `rw` | Read the software-written register value |
| `wo` | Read the software-written value in hardware; software readback is unavailable |
| `ro` | Supply `<register>_nxt` and `<register>_nxt_v` for registered readback |
| `wr_evt` | Read the software-written value and `<register>_wr_evt` indication |
| `rd_evt` | Supply hardware updates and observe `<register>_rd_evt` |
| `none` | Reserve address space without generating storage or application signals |

Register arrays expose corresponding unpacked arrays of values, update
enables, and event signals. Application updates and access events use the
register block's clock domain. An event does not automatically implement
application behavior such as clearing a counter or launching an operation.

Access modes select storage behavior and the generated agent methods.
The current RTL acknowledges reads and writes to every mapped register
address: writes to read-only storage have no effect, and reads of
write-only registers return `reg_pkg::BAD_ACCESS_DATA`. Unmapped or reserved
addresses produce an error response and failed reads return that same
constant. Byte-enabled writes update only selected storage bytes.

Generated decoders wrap the shared AXI4-Lite decoder with named downstream
ports and a generated address map. They route accesses in the upstream
control clock domain; clock-domain crossings belong in the surrounding
design. See [`reg.example`](../example/README.md) for block, decoder, and
clock-domain crossing integration.

## Verification agents

Each generated agent extends `reg_verif_pkg::reg_blk_agent` and provides
`read_<register>()` and `write_<register>()` methods as allowed by the
register access mode. Arguments use the generated register types; array
methods also take an `array_idx`. The constructor accepts a name and
`BASE_ADDR`, which is added to generated register offsets.

Attach a transport to the agent's public `reg_agent` handle, such as
`axi4l_verif_pkg::axi4l_reg_agent` for direct accesses or
[`reg_proxy_agent`](../proxy/README.md) for indirect accesses. The build
collects agent headers into a `<component>_reg_verif_pkg.sv` package, with
the component reference flattened using underscores, for example
`reg_example_reg_verif_pkg`.

## Build integration

The component's `regio/Makefile` includes
[`scripts/Makefiles/regio.mk`](../../../scripts/Makefiles/regio.mk) and
lists block specifications in `REG_BLOCK_YAML` and decoder specifications
in `REG_DECODER_YAML`. `REG_TOP_YAML` adds flattened top-level register-map
artifacts. The shared rules invoke Regio elaboration and generation,
create the generated component Makefiles, and support downstream
`<component>.regio.rtl` and `<component>.regio.verif` dependencies.

Under the component's build output directory, generated RTL goes into
`rtl/src/`, agent headers into `verif/include/`, and the verification
package into `verif/src/`. Flattened YAML maps go into `ir/`.
`REGIO_TEMPLATES_DIR` selects the template directory and defaults to this
one; override it to use a compatible replacement set.

Maintain YAML and templates as sources. After changing templates or an
indirectly included YAML file, clean and regenerate the affected component:

```sh
# Example consumer, run from this directory
make -C ../example/regio/ clean
make -C ../example/regio/ reg
```

RTL and agent generation rules track the listed source YAML timestamps,
but do not directly track template changes or transitive YAML includes.
Flattened IR refreshes on each generation invocation; that refresh alone
does not force existing RTL or agent headers to be regenerated.

## Verification

There is no standalone template test suite. The
[`reg.example`](../example/README.md), [`reg.endian`](../endian/README.md),
and [`reg.proxy`](../proxy/README.md) integration suites exercise generated
blocks and agents, with decoder and clock-domain crossing coverage in the
examples. When changing templates, regenerate affected consumers before
running their suites. Their READMEs describe the test entry points and
capabilities.
