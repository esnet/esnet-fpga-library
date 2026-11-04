# AXI4-Lite

AXI4-Lite interfaces, register access endpoints, interconnect, pipelines,
and protocol adapters. The library provides RTL for connecting register
blocks across clock domains and physical regions, plus an agent for
transaction-based verification.

## Contents

| Component | Description |
|-----------|-------------|
| `axi4l_pkg` | Bus-width selection, response encodings, and width helpers |
| `axi4l_intf` | AXI4-Lite signals, modports, and clocking block |
| Interface helpers | Direct connectors, controller/peripheral terminators, and flattened-signal adapters |
| `axi4l_controller` | Converts simple read/write requests into AXI4-Lite transactions |
| `axi4l_peripheral` | Converts AXI4-Lite accesses into simple read/write requests |
| `axi4l_reg_peripheral` | Connects an AXI4-Lite peripheral to `reg_intf` |
| `axi4l_decoder` | Decodes address regions and routes accesses to client interfaces |
| `axi4l_intf_cdc` | Transfers register accesses between controller and peripheral clock domains |
| `axi4l_pipe` | Fixed-depth pipelining of the AXI4-Lite channels |
| `axi4l_pipe_auto` | Pipelining with stages that the implementation tools can allocate |
| `axi4l_pipe_slr` | SLR-crossing pipeline with optional stages before and after the crossing |
| `axi4l_to_bus_adapter`, `axi4l_from_bus_adapter` | Map AXI4-Lite channels to and from generic `bus_intf` channels |
| `axi4l_apb_bridge` | Direct AXI4-Lite to APB register bridge |
| `axi4l_apb_proxy` | Register-indirect access to an APB address space |
| `axi4l_proxy` | Register-indirect access to another AXI4-Lite address space |
| `axi4l_from_axi4_adapter` | Converts single-beat accesses on a wide AXI4 bus into 32-bit AXI4-Lite accesses |
| `axi4l_reg_agent` | Register verification agent using an AXI4-Lite virtual interface |

`axi4l.rtl` depends on `bus.rtl`, `sync.rtl`, `reg.rtl`, `reg.proxy.rtl`,
`mem.rtl`, `util.rtl`, `apb.rtl`, `axi4.pkg`, and `axi4.rtl`.
`axi4l.verif` adds dependencies on `std.verif` and `reg.verif`.

## Interface and configuration

`axi4l_intf` takes an `ADDR_WID` parameter, defaulting to 32 bits, and a
`BUS_WIDTH` selected from `axi4l_pkg`:

| Value | Data width | Write strobe width |
|-------|------------|--------------------|
| `AXI4L_BUS_WIDTH_32` | 32 bits | 4 bytes |
| `AXI4L_BUS_WIDTH_64` | 64 bits | 8 bytes |

The default is `AXI4L_BUS_WIDTH_32`. `get_axi4l_bus_width_in_bytes()` returns
the corresponding byte count. The interface exposes derived `DATA_WID`
and `DATA_BYTE_WID` constants.

The `controller` and `peripheral` modports carry the write-address (AW),
write-data (W), write-response (B), read-address (AR), and read-data (R)
channels. Transfers occur on rising `aclk` edges when both valid and ready
are asserted. Addresses are byte addresses; `wstrb` selects the bytes to
write. `aresetn` is active low.

Each channel source holds valid and its payload stable while waiting for
ready. AW and W can arrive independently; a write requires both transfers
and completes with the B response. A read starts with an AR transfer and
completes with an R transfer carrying data and a response code. AXI4-Lite
uses single-beat accesses without burst-length fields or transaction IDs.

`resp_t` provides an `encoded` enum view and a `raw` two-bit view of the
response. Encodings include `RESP_OKAY`, `RESP_SLVERR`, and `RESP_DECERR`;
`RESP_EXOKAY` is also defined in the package.

The interface source also supplies:

- `axi4l_intf_connector` for direct interface connections.
- `axi4l_intf_controller_term` and `axi4l_intf_peripheral_term` for unused
  interface endpoints.
- `axi4l_intf_from_signals` and `axi4l_intf_to_signals` for connecting
  flattened AXI4-Lite ports.

## Register access endpoints and decoding

`axi4l_controller` accepts separate `wr` and `rd` requests with addresses,
write data, and byte strobes. It returns acknowledgement pulses, read data,
and response codes. Assert each request for one cycle and wait for its
acknowledgement before starting another request in that direction.
`WR_TIMEOUT` and `RD_TIMEOUT` default to 128 clock cycles; set a timeout to
zero to disable it. The controller drives the AXI4-Lite clock and reset
from its `clk` and active-high `srst` inputs.

`axi4l_peripheral` implements the complementary interface. It accepts
independently arriving write-address and write-data channels, combines them
into a write request, and waits for the downstream acknowledgement before
responding. Reads use their own request/acknowledgement path. It exposes the
interface clock and an active-high synchronous reset to the downstream
logic. `axi4l_reg_peripheral` packages these signals into `reg_intf`, mapping
register errors to `RESP_SLVERR`.

`axi4l_decoder` takes a `reg_pkg::map_spec_t` parameter named `MEM_MAP`.
`NUM_REGIONS` sets the number of client interfaces; each region specifies a
byte-addressed `base` and `size`. The decoder subtracts the selected base
before forwarding the address, allowing nested decoders. Unmapped accesses
return `RESP_DECERR`; read decode errors return `reg_pkg::BAD_ACCESS_DATA`.
Mapped client response codes propagate upstream.

## Clock crossing and pipelines

`axi4l_intf_cdc` terminates accesses in the source clock domain, transfers
request/response contexts through synchronizers, and issues new AXI4-Lite
transactions in `clk_to_peripheral`. Its `ADDR_WID` and `BUS_WIDTH`
parameters must match the connected interfaces. Reset is propagated from
the controller side into the destination domain.

The pipeline modules keep all channels within one clock domain. Their
connected interfaces must have matching address and data widths.

| Module | Configuration |
|--------|---------------|
| `axi4l_pipe` | `STAGES=1` by default; pipelines both valid and ready directions |
| `axi4l_pipe_auto` | Fixed pipeline stages plus stages available for automatic allocation by the implementation tools |
| `axi4l_pipe_slr` | SLR-crossing stage with `PRE_PIPE_STAGES=0` and `POST_PIPE_STAGES=0` by default |

The bus adapters expose each channel as a separate `bus_intf`, allowing the
same generic bus infrastructure to carry address, data, and response
payloads. They preserve channel handshake semantics.

## Bridges and proxies

`axi4l_apb_bridge` converts direct AXI4-Lite accesses into APB accesses using
`reg_intf`. `axi4l_apb_proxy` and `axi4l_proxy` instead use the `reg.proxy`
command register interface to address a downstream space indirectly. Use
the corresponding register-proxy access procedure rather than treating the
proxy window as directly mapped memory.

`axi4l_from_axi4_adapter` selects a 32-bit word lane from a wider AXI4 beat
and forwards it to a 32-bit AXI4-Lite target. On reads, it places the response
in the selected lane and zeroes the remaining lanes. Byte strobes select
written bytes; response IDs and user fields are preserved. The adapter is
intended for naturally aligned accesses of at most four bytes. Multi-beat
bursts are rejected with `SLVERR`. Read and write paths operate independently
without imposing ordering between them.

## Verification agent

`axi4l_verif_pkg::axi4l_reg_agent` extends `reg_verif_pkg::reg_agent` and
uses a virtual `axi4l_intf` named `axil_vif`. Its address and bus-width
parameters match those of the interface. Assign the virtual interface before
using the agent and call `idle()` to initialize its controller outputs.

The inherited register API supports word and byte accesses, response-error
checks, and transaction timeouts. Constructor arguments `WR_TIMEOUT` and
`RD_TIMEOUT` default to 256 cycles. `set_random_aw_w_alignment()` enables
independent randomized delays on the write-address and write-data channels;
this is disabled by default. `wait_n()` waits in AXI4-Lite clock cycles.

Transaction sequencing, controller initialization, and clock-cycle waits
belong to the agent. Use `idle()`, `read_reg()`, `write_reg()`, `read_byte()`,
`write_byte()`, and `wait_n()` there. The interface provides signals,
modports, and the `cb` clocking block for stimulus and response sampling.

## Verification

The SVUnit suites exercise register reads/writes, byte strobes, randomized
traffic, and response errors through interface connections, clock crossing,
and pipeline components. Decoder tests include nested address maps,
unmapped accesses, and missing peripherals. APB bridge/proxy tests exercise
direct and register-indirect access. AXI4 adapter tests check word-lane
selection, byte writes, response metadata, and rejection of multi-beat
bursts.

These are register-access tests rather than exhaustive AXI protocol
verification. Examples use a 32-bit AXI4-Lite register bus and a wider AXI4
source for the AXI4 adapter; they do not cover every width or parameter
combination.

```sh
# Single testbench
make -C tests/axi4l_intf/
make -C tests/axi4l_decoder/
make -C tests/axi4l_apb_bridge/
make -C tests/axi4l_apb_proxy/
make -C tests/axi4l_from_axi4_adapter/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
