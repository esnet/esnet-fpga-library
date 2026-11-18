# Registers

Register storage primitives, a request/acknowledge interface, and verification
agents for generated register maps. The library also provides Regio templates,
worked integration examples, an endianness checker, and an indirect-access
proxy. `reg.rtl` has no library dependencies; the AXI4-Lite wrappers and
verification components declare their dependencies separately.

## Contents

| Component | Description |
|-----------|-------------|
| `reg_pkg` | Address-map types, decoding helpers, and failed-access data |
| `reg_intf` | Clocked register read/write requests, byte enables, and responses |
| `reg_rw`, `reg_wo` | Software-written storage with byte enables |
| `reg_ro` | Hardware-updated storage for software readback |
| `reg_wr_evt`, `reg_rd_evt` | Storage with write/read event indications |
| `reg_agent` | Abstract register transport for verification |
| `reg_blk_agent` | Base class for generated, named-register agents |

## Register primitives

The storage primitives use `clk` and active-high synchronous `srst`.
`WID` defaults to 32 bits. Their `INIT_VALUE` input defaults to zero and is
loaded on reset; storage also initializes to zero before a reset occurs.

`reg_rw` updates when both `wr` and `wr_en` are asserted, changing only
bytes selected by `wr_byte_en`. `WR_DATA_BYTES` defaults to `4`; choose a
write-data width large enough to contain `WID`. Unselected bytes retain
their previous values. `reg_wo` uses the same storage implementation:
software read permissions are enforced by the surrounding register block,
while its `rd_data` port exposes the stored value to hardware.

`reg_ro` captures `upd_data` when `upd_en` is asserted. Reset takes priority
over writes and hardware updates.

`reg_wr_evt` adds a registered indication of `wr && wr_en`, independent of
the byte-enable values. Consecutive writes can keep this indication high
for consecutive cycles. `reg_rd_evt` adds a combinational `rd && rd_en`
indication to hardware-updated storage. These indications allow register
accesses to trigger commands or side effects in the surrounding logic.

## Register interface and address maps

`reg_intf` defaults to a 32-bit address and four data bytes. The controller
supplies `clk`, `srst`, and independent write/read requests. Writes carry
an address, data, and byte enables; reads carry an address. The peripheral
returns acknowledgements and error indications, plus read data. The
interface declares signals and controller/peripheral modports; transaction
sequencing belongs to the connected logic and verification agents.

| Path | Controller to peripheral | Peripheral to controller |
|------|--------------------------|--------------------------|
| Write | `wr`, `wr_addr`, `wr_data`, `wr_byte_en` | `wr_ack`, `wr_error` |
| Read | `rd`, `rd_addr` | `rd_ack`, `rd_data`, `rd_error` |

Requests and acknowledgements are sampled on rising `clk` edges. Qualify
write errors with `wr_ack` and read data/errors with `rd_ack`. There is no
request-ready signal or response backpressure. The connected endpoint
defines request capacity and how long request context must remain stable;
do not assume that the interface queues requests. For example, the supplied
APB controller serializes reads and writes and requires context to remain
valid through setup. Supplied register maps use byte addresses, with byte
enable bit zero selecting the least-significant data byte.

`reg_pkg` defines `region_spec_t` and `map_spec_t`, with storage for up to
32 address regions. `decode()` returns the matching region, address offset,
and an error flag. Its region test includes both `base` and `base + size`,
and the last matching region wins if regions overlap. `BAD_ACCESS_DATA`
is `32'hDEADBEEF` for failed register accesses.

## Related components

The register infrastructure has separate guides for its generated components
and integration examples:

| Library | Description |
|---------|-------------|
| [`reg.endian`](endian/README.md) | Scratchpads and monitors for checking register byte ordering |
| [`reg.proxy`](proxy/README.md) | Indirect register access hardware, verification agent, and Python protocol |
| [`reg.example`](example/README.md) | Worked register-block, decoder, and clock-domain crossing examples |
| [Regio templates](regio-templates/README.md) | Generated RTL and agent conventions, build integration, and regeneration |

Regio YAML specifications and these templates are the sources for generated
register packages, interfaces, AXI4-Lite blocks, decoders, and verification
agents. Generated artifacts belong in the build output tree.

## Verification agents

`reg_verif_pkg::reg_agent` is an abstract transport with configurable
address/data widths, defaulting to 32 bits. Derived agents implement word
and byte reads/writes and a transport-specific `wait_n(cycles)`. Public
methods serialize accesses and report transport errors or timeouts.

| API | Capability |
|-----|------------|
| `write_reg()`, `read_reg()` | Word register access |
| `write_byte()`, `read_byte()` | Byte register access |
| `check_reg()` | Read a register and compare its value |
| `write_bad_addr()`, `read_bad_addr()` | Check that invalid accesses produce errors rather than successful responses or timeouts |
| `set_wr_timeout()`, `set_rd_timeout()` | Configure limits interpreted by the derived transport |

`reg_blk_agent` adds a base address to register offsets and delegates to
its public `reg_agent` handle. Generated block agents extend it with typed,
per-register methods. Construct a generated agent with the desired base
offset and attach a transport such as
`axi4l_verif_pkg::axi4l_reg_agent` to its `reg_agent` handle.

## Verification

The example, endian, and proxy sub-libraries provide SVUnit integration
suites for generated register maps, decoder routing, byte ordering, and
indirect access. Their READMEs describe the available test capabilities
and individual test entry points.

Run all register library suites from this directory:

```sh
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
