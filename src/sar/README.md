# Segmentation and Reassembly

Frame segmentation and out-of-order reassembly RTL, packet/memory adapters,
and transaction-based verification support. The library separates segment
bookkeeping from payload transport: descriptor-only blocks track frame
buffers, offsets, lengths, fragment merging, and expiry; packet wrappers
also move payload bytes between packet interfaces and external memory.

## Contents

| Component | Description |
|-----------|-------------|
| `sar_pkg` | Payload-mode definitions and reassembly notification types |
| `sar_segmentation` | Converts a frame descriptor into segment descriptors using a register-configured segment length |
| `sar_reassembly` | Tracks incoming segment descriptors, coalesces adjacent fragments, and reports completed frames or expires incomplete fragments |
| `sar_reassembly_cache` | Append/prepend lookup tables, fragment allocation, and fragment creation/extension/merge reporting |
| `sar_reassembly_htable` | CRC-hashed cuckoo tables and backing storage used by fragment tracking |
| `sar_reassembly_state` | Per-fragment state, completion/expiry processing, cache cleanup, and fragment-pointer reclamation |
| `sar_reassembly_state_check` | Classifies stored fragments as complete or expired using configurable timeout and timer state |
| `sar_packet_segmentation` | Reads frame payload from external memory and emits segment packets with sideband frame-buffer metadata |
| `sar_packet_reassembly` | Writes accepted packet payload to frame memory and feeds segment metadata into the reassembly controller |
| `sar_segment_to_packet` | Unpacks segment packet metadata into the narrow packet interface and reassembly sidebands |
| `sar_segment_from_packet` | Combines packet metadata and segmentation sidebands into stable segment metadata |
| `sar_verif_pkg` | Frame/segment transactions, sequencing and collection, reference model, packet transport adapters, component environment, and register agents |

## Descriptor interfaces

The descriptor-only blocks do not carry payload bytes. All lengths and
offsets are expressed in bytes; buffer IDs identify frame contexts owned
by the surrounding application. Transfers use the rising edge of `clk`.
`srst` resets the block, `en` enables operation, and `init_done` reports
initialization of the connected bookkeeping components.

### Frame descriptors

`sar_segmentation` consumes frame descriptors and `sar_reassembly`
produces completion descriptors. Signal directions below are relative to
the segmentation block; they reverse for reassembly.

| Signal | Direction | Description |
|--------|-----------|-------------|
| `frame_valid` | in | Frame descriptor is valid |
| `frame_ready` | out | Block can accept the descriptor |
| `frame_buf_id` | in | Frame-buffer ID, sized by `BUF_ID_WID` |
| `frame_len` | in | Frame byte length, sized by `FRAME_SIZE_WID` |

A descriptor transfers when valid and ready are both asserted. Hold the
buffer ID and length stable until acceptance. Reassembly reports a frame
when its final segment has arrived and the coalesced coverage starts at
byte zero. Assert completion readiness when able to accept a frame; the
reassembly state controller uses readiness to begin presenting queued
completions.

### Segment descriptors

`sar_segmentation` produces segment descriptors; `sar_reassembly` and
`sar_reassembly_cache` consume them. Directions below are relative to
segmentation.

| Signal | Direction | Description |
|--------|-----------|-------------|
| `seg_valid` | out | Segment descriptor is valid |
| `seg_ready` | in | Consumer can accept the descriptor |
| `seg_buf_id` | out | Frame-buffer ID associated with this segment |
| `seg_offset` | out | Byte offset within the frame |
| `seg_len` | out | Segment length in bytes |
| `seg_last` | out | Segment contains the end of the frame |

Hold all segment fields stable while stalled. Segmentation starts at offset
zero, advances by each segment's length, and marks the final descriptor
with `seg_last`. Configure a nonzero segment length through the register
agent before submitting frames. The final segment can be shorter than the
configured length.

Reassembly accepts reordered and interleaved descriptors. An isolated
segment creates a fragment; adjacent segments extend or merge existing
fragments. Fragment endpoints use a half-open byte range
`[offset_start, offset_end)`. `seg_last` identifies the frame endpoint even
when that segment arrives before earlier segments.

## Fragment tracking and expiry

The reassembly cache indexes fragments by buffer ID and boundary offset,
using append and prepend tables to locate neighboring fragments. It emits
unbackpressured fragment updates containing the fragment pointer, buffer
ID, start/end offsets, last flag, and any merged pointer. The state block
consumes those updates, scans fragment state, and returns allocated
pointers when fragments complete, merge, or expire.

`MAX_FRAGMENTS` bounds disjoint fragments across all frame contexts, rather
than the number of received segments. `BURST_SIZE` configures buffering
for fragment-table updates. Input queues can backpressure segment
acceptance. If an accepted segment needs a new fragment after the pointer
allocator is exhausted, it is dropped and counted. The standalone cache
exposes pointer deallocation and
management interfaces; the complete reassembly block connects these to
its state and cleanup logic.

Expiry uses an external `ms_tick` input and a register-configured timeout.
The timer width and tick period determine the available age range. Expiry
removes incomplete fragment state and its lookup-table entries so the
resources can be reused. Register agents expose initialization, timeout
configuration, completion/expiry counters, and fragment/cache statistics.

The bookkeeping operates on segment boundaries; it does not perform
payload comparison or define a general duplicate/overlap reconciliation
policy. Supply segment descriptors consistent with the application's
frame layout.

## Packet and memory integration

The packet wrappers use [`packet_intf`](../packet/README.md) for payload
transport and the memory library's read/write interfaces for external
storage. Frame buffer IDs select memory regions; offsets select byte
positions within those regions. Buffer ownership and payload-memory
allocation remain the consumer's responsibility.

`sar_packet_segmentation` reads payload for each generated segment and
emits `packet_buf_id`, `packet_offset`, `packet_size`, and `packet_last`
alongside the packet stream. `sar_packet_reassembly` consumes the
corresponding sidebands, writes packet bytes into memory, and submits the
accepted packet's descriptor to reassembly. Errored packets are dropped by
the packet-write path and counted rather than added to fragment tracking.

Memory addresses concatenate the buffer ID with the word-address portion
of the byte offset. Choose buffer-region geometry consistent with that
mapping. Segment starts must be aligned to `packet_if.DATA_BYTE_WID`;
there is no byte-shifting path for unaligned starting offsets. Configure
segmentation lengths accordingly. Packet size limits and final partial-word
handling follow the packet read/write components.

The segment transport representation packs packet metadata as
`{buf_id, offset, last, opaque}`. `sar_segment_to_packet` splits those fields
for the reassembly wrapper. `sar_segment_from_packet` captures sidebands
at the first accepted beat and retains them through the packet so a
monitor can recover consistent metadata at its end.

The packet wrappers implement direct placement in frame memory. Although
`sar_pkg` defines scatter/gather terminology, the design notes in
[`doc/sar_sg.md`](doc/sar_sg.md) describe a separate architectural direction,
not a selectable scatter/gather payload datapath in these wrappers.

RTL dependencies include packet, memory, FIFO, CRC, database, hash-table,
state, allocator, and AXI4-Lite support. Registers are generated from
`regio/`. Bookkeeping interfaces reuse the database and state libraries;
there are no additional SystemVerilog interface types defined here.

## Verification components

`sar_frame_transaction` holds complete frame bytes and buffer identity;
`sar_segment_transaction` adds offset, final-segment indication, and error
status. `sar_sequencer` decomposes frames into configurable-length segments,
with ordering, interleaving, and missing-segment stimulus. `sar_collector`
reconstructs frames from received segment bytes and endpoints; its byte
counting assumes segments do not duplicate or overlap covered bytes.

`sar_segment_driver` and `sar_segment_monitor` pack/unpack metadata and
delegate transport to packet agents. `sar_model` provides the frame-level
reference path. `sar_component_env` connects the sequencer, transport,
collector, model, and scoreboard. Register agents configure segmentation,
reassembly, caches, expiry checks, and their subordinate state/hash-table
blocks.

## Verification

The SVUnit suites exercise segmentation descriptors, fragment-cache
creation/append/prepend/merge behavior, reassembly ordering and expiry,
packet/memory integration, and the verification components themselves.
Directed and randomized checks include interleaved frames, reversed and
shuffled segment order, missing segments, backpressure, transmit gaps,
resource exhaustion/reuse, register counters, reset, and errored packets.
Individual testbenches define detailed configurations and coverage.

```sh
# Single testbench
make -C tests/sar_reassembly/

# Full regression
make -C tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
