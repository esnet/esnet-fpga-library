# Packet

Generic packet-stream interfaces, buffering and memory-backed packet paths,
and verification components. The library provides protocol-independent
streaming RTL together with raw/Ethernet packet transactions and drivers,
monitors, reference models, and register agents.

## Contents

| Component | Description |
|-----------|-------------|
| `packet_pkg` | Protocol identifiers, packet size/checksum types, status codes, and arbitration modes |
| `packet_eth_pkg` | Ethernet address, EtherType, and MAC header definitions |
| `packet_ipv4_pkg` | IPv4 header field types and packed header definition |
| `packet_tcp_pkg` | TCP sequence-number type |
| `packet_intf` | Packet data stream, clocking blocks, connectors, tie-offs, metadata replacement, and packet-boundary mux/demux helpers |
| `packet_descriptor_intf` | Address, length, error, metadata, and checksum descriptors, with connector/delay/metadata helpers |
| `packet_event_intf` | Packet completion events with status and byte length |
| `packet_pipe`, `packet_pipe_auto`, `packet_pipe_slr`, `packet_skid_buffer` | Stream pipelining and backpressure buffering |
| `packet_width_converter`, `packet_to_bus_adapter`, `packet_from_bus_adapter` | Stream-width conversion and bus-interface adaptation |
| `packet_sop`, `packet_cksum`, `packet_crc_rx`, `packet_crc_tx` | Packet-boundary tracking, one's complement checksum, and CRC processing |
| `packet_write`, `packet_read` | Packet storage/retrieval using memory and descriptor interfaces |
| `packet_fifo`, `packet_fifo_core`, `packet_descriptor_fifo` | Packet and descriptor buffering, including configurable clock-domain crossings |
| `packet_scatter`, `packet_gather`, `packet_sg_core` | Packet storage across allocated buffers and descriptor-linked retrieval |
| `packet_enqueue`, `packet_dequeue`, `packet_q_core`, `packet_q_manager` | Packet queue insertion, retrieval, and queue management |
| `packet_aggregate`, `packet_disaggregate` | Combining packet inputs into a shared path and distributing packet outputs |
| `packet_capture`, `packet_playback`, `packet_counters`, `packet_loopback` | Register-controlled capture/playback, packet statistics, and loopback routing |
| `packet_verif_pkg` | Packet/descriptor transactions, stream drivers and monitors, component environments, models, and register agents |

## Interfaces

### `packet_intf` — packet data stream

Carries packet payload bytes with ready/valid flow control, an end-of-packet
marker, and application-defined metadata. Packets can span any number of
beats, and the transmitter or receiver can insert stalls between beats.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_BYTE_WID` | `1` | Number of payload bytes per beat |
| `META_WID` | `1` | Width of the application metadata field |

`MTY_WID` is derived as `max(1, $clog2(DATA_BYTE_WID))`. The interface also
provides `data_t` and `mty_t` typedefs matching its data and empty-byte fields.

Directions below are relative to the transmitter (`tx` modport).

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | in | 1 | Transfer clock; handshakes occur on rising edges |
| `vld` | out | 1 | The transmitter is offering a valid beat |
| `rdy` | in | 1 | The receiver can accept the offered beat |
| `data` | out | `DATA_BYTE_WID * 8` | Payload bytes, declared as `[0:DATA_BYTE_WID-1][7:0]` |
| `eop` | out | 1 | Marks the final beat of the packet |
| `mty` | out | `MTY_WID` | Number of trailing empty bytes on the final beat |
| `err` | out | 1 | Packet error indication, normally interpreted on the final beat |
| `meta` | out | `META_WID` | Application-defined packet metadata |

A beat transfers when `vld && rdy` is true on a rising clock edge. Once a
beat is offered, the transmitter holds `vld` and all associated fields stable
until acceptance. An idle cycle (`vld=0`) does not end a packet. Consecutive
beats, including the end of one packet and the start of the next, can transfer
on consecutive clock edges without an idle gap.

`data[0]` is the first byte in stream order. Non-final beats contain
`DATA_BYTE_WID` valid bytes and use `mty=0`. On the final beat, valid bytes
occupy indices `0` through `DATA_BYTE_WID-mty-1`; trailing bytes are ignored.
The valid range of `mty` is `0` through `DATA_BYTE_WID-1`, so an accepted beat
always carries at least one byte. For example, an 18-byte packet on an
8-byte interface uses two full beats followed by a beat with `eop=1`,
`mty=6`, and valid payload in `data[0]` and `data[1]`.

There is no explicit start-of-packet signal. The first accepted beat after
reset or an accepted `eop` begins a packet; `packet_sop` supplies an explicit
indication where needed. A single-beat packet asserts `eop` on its only beat.
Keep metadata constant across a packet unless the connected modules specify
another policy; some modules latch it at the start or end of a packet.

Connector, termination, metadata-replacement, and mux/demux helpers are
provided alongside the interface. Mux/demux selection changes apply at packet
boundaries and preserve an already offered stalled beat.

### `packet_descriptor_intf` — packet storage descriptor

Transfers a packet's storage location and attributes independently of its
payload stream. Each handshake transfers one complete descriptor; there are
no multi-beat descriptors or start/end markers on this interface.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ADDR_WID` | `1` | Width of the packet address or buffer pointer |
| `META_WID` | `1` | Width of the application metadata field |
| `MAX_PKT_SIZE` | `16383` | Maximum packet length in bytes; determines the length-field width |

`SIZE_WID` is derived as `$clog2(MAX_PKT_SIZE+1)`. This differs from
`packet_pkg::size_t`, which is a fixed-width packet size type.

Directions below are relative to the descriptor transmitter (`tx` modport).

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | in | 1 | Transfer clock; handshakes occur on rising edges |
| `vld` | out | 1 | The transmitter is offering a valid descriptor |
| `rdy` | in | 1 | The receiver can accept the offered descriptor |
| `addr` | out | `ADDR_WID` | Packet storage address or buffer pointer |
| `size` | out | `SIZE_WID` | Packet length in bytes |
| `err` | out | 1 | Packet error indication |
| `meta` | out | `META_WID` | Application-defined packet metadata |
| `cksum` | out | `packet_pkg::CKSUM_FIELD_WID` (16) | Optional one's complement checksum; zero means not calculated |

A descriptor transfers when `vld && rdy` is true on a rising clock edge.
The transmitter holds `vld`, `addr`, `size`, `err`, `meta`, and `cksum` stable
while stalled. Descriptors can transfer on consecutive clock edges.

`addr` is interpreted by the consuming storage path; the interface does not
impose byte addressing. For example, packet read/write paths use memory-word
addresses, while scatter/gather paths use allocated-buffer pointers. `size`
always describes a byte length and must fit the configured `MAX_PKT_SIZE`.
Checksum-enabled storage paths compute or verify `cksum`; a zero value
indicates that checksum information is absent.

The accompanying helpers connect descriptors, insert forward-path delay,
replace metadata, or buffer descriptors through `packet_descriptor_fifo`.

### `packet_event_intf` — packet completion notification

Reports completion information independently of the packet data and storage
descriptor interfaces. The `publisher` modport drives `evt`, a 32-bit byte
`size`, and `packet_pkg::status_t status`; `subscriber` receives them.

Each rising `clk` edge with `evt=1` reports one event. `size` and `status`
are meaningful on that edge; they need not remain valid when `evt=0`.
Consecutive events can occur on consecutive cycles. There is no ready or
acknowledgement signal, so subscribers must accept every event. The
interface provides no buffering, reset, or clock-domain crossing.

### RTL and verification connections

`packet_intf` and `packet_descriptor_intf` expose `tx` and `rx` modports.
The receiver's directions reverse the transmitter directions listed above,
with `clk` an input on both sides. Reset
is supplied separately to the connected modules; neither interface contains
a reset signal.

For verification, `cb_tx` and `cb_rx` provide transmitter and receiver
clocking blocks on the rising edge of `clk`, using implicit default skews.
The packet and descriptor drivers/monitors perform timed transfers through
these clocking blocks, as described below.

## Buffering and processing

Packet FIFO blocks provide configurable store-and-forward/cut-through
operation, packet-size limits, error handling, and ready behavior. Memory
interfaces separate packet storage from the choice of RAM implementation.
Scatter/gather blocks divide storage into allocated buffers and link their
descriptors; queue blocks build packet queues on that storage. Parameters
control buffer sizes, memory latency, concurrency, and optional checksum
processing. See the [queue architecture notes](doc/packet_qs.md) for design
background.

CRC blocks use `crc_pkg` configuration and the shared software CRC reference
model. `packet_crc_tx` produces an out-of-band CRC on the accepted output
end-of-packet beat; it does not append an FCS. `packet_crc_rx` compares the
stream CRC with `crc_in` supplied on the input end-of-packet beat and marks
mismatches through the output error indication. Register-controlled
capture/playback and counters use generated register definitions from
`regio/`. RTL dependencies include the standard,
FIFO, memory/proxy, allocation, arbitration, and CRC libraries.

## Verification components

`packet` defines the common transaction API, including byte access, metadata,
error state, copying, comparison, and CRC calculation. `packet_raw` stores
arbitrary payload bytes; `packet_eth` represents an Ethernet header and
payload. `packet_descriptor` represents memory-backed packet metadata.

Stream and descriptor drivers/monitors support transaction objects;
packet stream components also provide configurable stalls. Timed stream
operations live in these verification classes: `send_beat()` and
`receive_beat()` transfer individual packet beats, while descriptor drivers
and monitors expose `send_raw()` and `receive_raw()`. Their `MAX_PKT_SIZE`
parameter must match the descriptor interface. Drivers/monitors provide
`idle()` and `wait_n()` for interface control; monitors provide `flush()` to
hold readiness high. The RTL interfaces retain signals and clocking blocks.

Component environments connect stimulus, a reference model, and a scoreboard.
Register-backed capture/playback agents provide packet access through the
control interface, and packet drivers can load stimulus from PCAP files.
Ethernet deserialization through `packet_eth::from_bytes()` is unimplemented;
the IPv4/TCP packages provide types rather than complete transaction models.
Verification dependencies include `std.verif`, PCAP/string helpers, and the
memory, allocation, register, and CRC verification libraries.

## Verification

The SVUnit suites are grouped by integration level:

| Test directory | Capability |
|----------------|------------|
| `tests/0` | Packet transactions and interfaces, pipeline/FIFO/width-conversion paths, memory read/write and enqueue behavior, CRC processing, and loopback routing |
| `tests/1` | Packet-boundary mux/demux behavior and register-controlled capture/playback |
| `tests/2` | Aggregation/disaggregation, queue management, and scatter/gather integration, including overflow handling |

The suites use packet/descriptor reference models and scoreboards, directed
checks, and randomized payloads or stalls where appropriate. Configurations
exercise features such as checksum generation/checking, packet-size limits,
and ready handling; individual testbenches define the detailed coverage.

```sh
# Single testbench
make -C tests/0/packet_intf/

# Run an integration level
make -C tests/0/regression/
make -C tests/1/regression/
make -C tests/2/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
