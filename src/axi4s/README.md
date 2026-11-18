# AXI4-Stream

AXI4-Stream interfaces, packet-stream processing RTL, and verification agents.
The library provides ready/valid transport with byte enables and metadata,
plus buffering, routing, width conversion, header processing, and
register-controlled capture/playback.

## Contents

| Component | Description |
|-----------|-------------|
| `axi4s_pkg` | Operating-mode definitions for ready handling, packet errors, probes, pipelines, and stream synchronization |
| `axi4s_intf` | AXI4-Stream signals, modports, clocking blocks, connectors, tie-offs, metadata replacement, and routing helpers |
| `axi4s_pipe`, `axi4s_pipe_auto`, `axi4s_pipe_slr`, `axi4s_skid_buffer` | Stream pipelining and backpressure buffering |
| `axi4s_fifo_core`, `axi4s_fifo_sync`, `axi4s_fifo_async` | Beat buffering with synchronous or independent input/output clocks |
| `axi4s_pkt_fifo_sync`, `axi4s_pkt_fifo_async` | Packet-aware buffering, configurable store-and-forward behavior, and packet discard/reporting |
| `axi4s_pkt_buffer` | Memory-backed packet storage with externally supplied read/write pointers |
| `axi4s_pkt_discard_err`, `axi4s_pkt_discard_ovfl` | Whole-packet discard for error or overflow handling |
| `axi4s_mux`, interface mux/demux helpers | Stream selection, arbitration, and routing |
| `axi4s_copy`, `axi4s_drop` | Packet copying and controlled discard |
| `axi4s_width_converter`, `axi4s_shift` | Beat-width conversion and byte shifting |
| `axi4s_pad`, `axi4s_trunc` | Minimum-length padding and maximum-length truncation |
| `axi4s_split`, `axi4s_join`, `axi4s_split_join`, `axi4s_sync` | Header extraction/replacement, packet association, and stream synchronization |
| `axi4s_to_bus_adapter`, `axi4s_from_bus_adapter` | Conversion between AXI4-Stream and the generic bus interface |
| `axi4s_to_packet_adapter`, `axi4s_from_packet_adapter` | Conversion between AXI4-Stream and `packet_intf`, including byte order and metadata mapping |
| `axi4s_packet_capture`, `axi4s_packet_playback` | AXI4-Lite controlled packet capture and injection |
| `axi4s_probe`, `axi4s_shaper` | Packet/byte statistics and burst/duty-cycle stream throttling |
| `axi4s_verif_pkg` | Transactions, active drivers/monitors, passive sampling, component environments, and register-backed capture/playback agents |

## `axi4s_intf`

The interface represents an AXI4-Stream channel with data, byte enables,
packet boundaries, and identifier/destination/user sidebands. Its signal
widths are explicit parameters; unused sidebands can be tied to zero.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_BYTE_WID` | `8` | Number of data bytes per beat |
| `TID_WID` | `1` | Stream identifier width |
| `TDEST_WID` | `1` | Destination identifier width |
| `TUSER_WID` | `1` | Application-defined user metadata width |

Directions below are relative to the transmitter (`tx` modport).

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `aclk` | in | 1 | Transfer clock; handshakes occur on rising edges |
| `tvalid` | out | 1 | The transmitter is offering a valid beat |
| `tready` | in | 1 | The receiver can accept the offered beat |
| `tdata` | out | `DATA_BYTE_WID * 8` | Payload, declared as `[DATA_BYTE_WID-1:0][7:0]` |
| `tkeep` | out | `DATA_BYTE_WID` | Byte enables; bit `i` qualifies `tdata[i]` |
| `tlast` | out | 1 | Marks the final beat of a packet |
| `tid` | out | `TID_WID` | Stream identifier |
| `tdest` | out | `TDEST_WID` | Routing destination |
| `tuser` | out | `TUSER_WID` | Application-defined sideband information |

A beat transfers when `tvalid && tready` is true on a rising clock edge.
The transmitter holds `tvalid` and all associated fields stable while
stalled. Packets can span multiple beats, with idle cycles between beats;
`tlast` completes a packet only when its beat is accepted. Back-to-back
packets do not require an idle gap. Start-of-packet is implicit after reset
or an accepted `tlast`.

Byte zero is the least-significant byte of `tdata` and the first byte in
stream order. For example, an 18-byte packet on an 8-byte interface uses two
full beats with `tkeep=8'hff`, then a final beat with `tlast=1` and
`tkeep=8'h03`. The remaining data bytes on that final beat are unqualified.
This lane ordering differs from the ascending byte indices of `packet_intf`;
the packet adapters perform the conversion.

The interface provides `tx`, `rx`, and passive `prb` modports. `cb_tx`,
`cb_rx`, and the read-only `cb` clocking block use the rising edge of `aclk`
and implicit default skews. Reset is supplied separately to the connected
modules; it is not an interface signal. There is no `tstrb` signal.

## Packet-processing conventions

Most packet processing paths use full non-final beats and contiguous valid
bytes starting at lane zero on the final beat. The AXI4-Stream to packet
adapter derives an empty-byte count from `tkeep`; it requires full non-final
beats and a nonempty, contiguous final beat starting at lane zero. It does
not compact sparse byte lanes, and `packet_intf` cannot represent a
zero-byte beat. Consult individual modules before using other byte-enable
patterns or changing sidebands within a packet.

`tid`, `tdest`, and `tuser` have application-defined meanings at the stream
boundary. Packet adapters take explicit metadata/error or sideband inputs,
so callers supply the mapping between packet metadata and stream sidebands.
The `PKT_ERROR` discard mode treats nonzero `tuser` on the first accepted
beat as a packet error indication. Header-processing paths use an
extended `tuser` layout to associate headers with buffered payload packets;
matching metadata widths and packet associations are required across the
split/join path.

FIFO variants provide different ready, overflow, packet-discard, and
store-and-forward policies. Synchronous and asynchronous wrappers support
single-clock and clock-domain-crossing paths respectively. Pipeline and skid
buffer modules accommodate backpressure latency. `IGNORE_TREADY` modes are
intended for sources that cannot be stalled and rely on the selected
buffering/discard policy.

Split/join blocks copy a configurable-length header for processing, buffer
the associated packet, and recombine a replacement header with its payload.
The suites exercise header growth, shrinkage, and packet drops. Padding,
truncation, shaping, and shifting are separate stream transformations.
Register-controlled blocks use generated definitions from `regio/`.

RTL dependencies include the bus, arbitration, register, FIFO, memory, and
packet libraries. Capture/playback reuses the packet library's storage and
control infrastructure.

## Verification components

`axi4s_transaction` represents packet bytes with typed `tid`, `tdest`, and
`tuser` fields. It extends the generic raw-packet transaction and provides
byte conversion, duplication, comparison, and metadata accessors.

`axi4s_driver` transmits transactions or PCAP stimulus; `axi4s_monitor`
receives transactions and compacts bytes qualified by `tkeep` into payload
arrays. Driver `twait` and monitor `tpause` settings insert cycle-based
transmit gaps and receive backpressure. Driver minimum-gap configuration
adds an inter-packet delay.

Timed beat transfers live in the verification classes: drivers provide
`send_beat()`, monitors provide `receive_beat()`, and `axi4s_sample` provides
`sample_beat()` and passive packet capture without driving `tready`.
Drivers/monitors expose `idle()` and `wait_n()`; monitors provide `flush()`
to hold readiness high. `axi4s_component_env` connects stream agents to a
reference model and scoreboard. Register-backed capture/playback agents
wrap the corresponding packet agents for software-controlled access.

Verification dependencies include `std.verif`, packet/PCAP helpers, and
register verification support. Payload transaction APIs represent complete
packets; beat-level APIs retain direct control of `tkeep`, `tlast`, and
sideband fields.

## Verification

The SVUnit suites are grouped by integration level:

| Test directory | Capability |
|----------------|------------|
| `tests/0` | Interfaces, pipelines, synchronous/asynchronous FIFOs, packet adapters, width conversion, padding/truncation, and header split/join behavior |
| `tests/1` | Register-controlled packet capture and playback, including PCAP stimulus |
| `tests/2` | Multi-stream arbitration and destination-based demultiplexing |

The suites combine transaction reference models and scoreboards with
directed checks, randomized packet data, passive capture, and configurable
transmit gaps or receive stalls. Individual testbenches define detailed
configurations and coverage, including header transformations and
packet-discard cases.

```sh
# Single testbench
make -C tests/0/axi4s_intf/

# Run an integration level
make -C tests/0/regression/
make -C tests/1/regression/
make -C tests/2/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
