# Allocation

Pointer-pool, linked-list, and scatter/gather allocators for memory and
transaction descriptors. `alloc.rtl` depends on `arb.rtl`, `mem.rtl`, and
`fifo.rtl`. AXI4-Lite control wrappers and verification agents are supplied
separately.

## Contents

| Component | Description |
|-----------|-------------|
| `alloc_pkg` | Parameterized scatter/gather descriptor type |
| `alloc_bv_core` | Bitmap pointer allocator using external state memory |
| `alloc_bv` | Bitmap allocator with internal RAM and optional parallel slices |
| `alloc_ll_core` | Linked-list queues with shared pointer allocation and external node memory |
| `alloc_scatter_core` | Build buffer chains and report completed frames |
| `alloc_gather_core` | Traverse descriptor chains and return buffers to the allocator |
| `alloc_sg_core` | Combined allocation, scatter, gather, and recycling |
| `alloc_intf` | Store/load request and descriptor-transfer interfaces |
| `alloc_intf_store_connector`, `alloc_intf_load_connector`, `alloc_intf_load_mux` | Interface connections and load selection |
| `alloc_mon_intf`, `alloc_mon_intf_connector`, `alloc_mon_pipe_auto` | Allocation events, failures, and pipelined monitoring |
| `alloc_axil_bv`, `alloc_axil_ll_core`, `alloc_axil_sg_core` | AXI4-Lite control and monitoring wrappers |
| `alloc_axil_core` | Shared register-control and monitoring implementation |
| `alloc_store_agent`, `alloc_load_agent` | Clocking-block store/load verification helpers |
| `alloc_reg_agent` | Software reset, information, statistics, and error access |

## Bitmap pointer allocation

`alloc_bv` manages a pool of up to `2**PTR_WID` pointers. A bitmap records
availability; a background scan reserves free pointers into an allocation
FIFO, while returned pointers enter a deallocation FIFO. Allocation can
therefore serve short bursts faster than the sustained bitmap scan rate.
Finding free pointers becomes slower as the pool fills.

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `PTR_WID` | `1` | Pointer width and maximum pool size |
| `ALLOC_Q_DEPTH` | `64` | Reserved-pointer queue depth |
| `DEALLOC_Q_DEPTH` | `32` | Returned-pointer queue depth |
| `ALLOC_FC` | `1` | Allocation requester observes readiness |
| `DEALLOC_FC` | `1` | Deallocation requester observes readiness |
| `NUM_SLICES` | `1` | Power-of-two parallel allocator slices |

`PTRS` limits the usable pool; zero selects the full pointer range.
`NUM_SLICES` partitions that pool across bitmap engines to improve
throughput. `alloc_bv_core` exposes the underlying memory interfaces for
applications that supply their own bitmap storage, with `MEM_RD_LATENCY`
describing that memory's read latency.

Use `clk` and active-high synchronous `srst`, and wait for `init_done`
before traffic. `en` controls operation and `scan_en` controls scanning for
free pointers. An allocation consumes the pointer presented on `alloc_ptr`;
a deallocation supplies `dealloc_ptr`. With flow control enabled, observe
`alloc_rdy` and `dealloc_rdy`. Without flow control, requests can fail when
the queues cannot serve or accept them; monitor the failure indications.

Monitoring distinguishes successful operations, queue failures, and bitmap
consistency errors such as returning a pointer that is already free.
Reserved pointers in the allocation queue are already removed from the
bitmap's free pool, even before an application requests them.

## Linked-list queues

`alloc_ll_core` maintains independently selected lists sharing an allocator
and external node memory. Stores append metadata to a selected list; loads
remove metadata from that list and release its node. Request readiness and
completion are separate: observe `store_rdy`/`load_rdy` when submitting
requests and `store_ack`/`store_nack` or `load_ack`/`load_nack` for results.

`LIST_CONTEXTS`, `PTR_WID`, and `META_WID` select list count, pool size, and
metadata width. `BUFFERS=0` selects the full pool; a nonzero value limits it.
`STORE_Q_DEPTH` and `LOAD_Q_DEPTH` default to `16`. Their flow-control
options default to enabled. `N_ALLOC` selects power-of-two allocator
parallelism, and `NUM_RD_TRANSACTIONS` sizes read-transaction tracking.

Supply compatible write/read memory interfaces, sufficient width for the
list node fields, and a valid `mem_init_done` indication. Wait for the
core's own `init_done` before issuing application requests.

## Scatter/gather chains

`alloc_intf` separates allocation/load requests from descriptor transfers.
Its geometry is set by `BUFFER_SIZE`, `PTR_WID`, and `META_WID`. The
`cb_store` and `cb_load` clocking blocks support verification using their
implicit default skews. Transaction sequencing is provided by agents.

A store request obtains an available buffer pointer. The store transfer
supplies the completed buffer pointer, end-of-frame status, size, metadata,
and error state. A load request supplies a chain pointer; accepted load
transfers return descriptor fields while the gather logic traverses the
chain.
Non-final buffers contribute `BUFFER_SIZE` to frame length, while the
final descriptor supplies its size contribution.

Both phases handshake on rising `clk` edges:

| Phase | Store path | Load path |
|-------|------------|-----------|
| Request (`req && rdy`) | Allocator returns the allocated `ptr` | Requester supplies the chain's starting `ptr` |
| Descriptor (`vld && ack`) | Requester supplies `nxt_ptr`, `eof`, `size`, `meta`, and `err` | Allocator returns the same descriptor fields |

Hold `req` until readiness; a load requester also holds `ptr` stable.
The descriptor source holds `vld` and its fields until `ack`. Despite its
name, the interface's `nxt_ptr` identifies the buffer being committed on
store or delivered on load. The scatter core builds stored next-buffer
links from successive store transfers; the gather core follows those links
internally. `eof` marks the end of a frame, `size` describes its final
buffer's byte contribution, and `meta`/`err` carry descriptor metadata and
error state. These are buffer pointers, rather than byte addresses. The
interface has no reset signal; reset the connected cores separately.

`alloc_scatter_core` arbitrates store contexts, writes descriptors, and
reports frame completion through `frame_valid`, `frame_ptr`, `frame_size`,
and `frame_error`. `alloc_gather_core` reads descriptors, delivers them to
load contexts, and returns consumed buffer pointers for reuse.
`alloc_sg_core` combines both with a bitmap allocator and a recycle path
for releasing a chain without delivering it through an application gather
context.

Configure descriptor memory to match
`alloc_pkg::alloc#(BUFFER_SIZE, PTR_WID, META_WID)::desc_t`, which contains
start/end flags, size, error, metadata, and the next pointer. Descriptor
size fields use `$clog2(BUFFER_SIZE)` bits; choose a buffer size greater
than one. Match `MEM_WR_LATENCY` to the supplied descriptor memory so frame
completion accounts for pending writes. The interfaces and memories use
the same clock; these cores do not provide clock-domain crossing.

`SCATTER_CONTEXTS`, `GATHER_CONTEXTS`, `PTR_WID`, `BUFFER_SIZE`,
`MAX_FRAME_SIZE`, and `META_WID` define the combined core's geometry.
`STORE_FC` and `LOAD_FC` control request flow control; `N_ALLOC` selects
allocator parallelism. Simulation options `SIM__FAST_INIT` and
`SIM__RAM_MODEL` control initialization and RAM modeling where supported.

## AXI4-Lite control and monitoring

`alloc.axil.rtl` wraps bitmap, linked-list, and scatter/gather allocators
with an AXI4-Lite register interface. `alloc_axil_core` implements shared
control, counters, and error tracking, crossing register accesses into the
allocator clock domain and pipelining monitor events. Register definitions
live under [`regio/`](regio/).

Registers expose pool capacity, initialization/enabled state, active and
debug operation counts, error flags, and the last offending pointer.
Software can request reset, control operation, and clear debug counters.
For the bitmap wrapper, the allocation-enable control gates background
scanning; pointers already queued can remain available. Error flags clear
on reads, so software should retain any flags it needs after observation.

`alloc_verif_pkg::alloc_reg_agent` wraps a register-agent transport and an
optional base offset. It provides readiness polling, `soft_reset()`,
capacity and counter queries, allocation scan control, and cached error
flag access.

## Store/load verification agents

`alloc.verif` also provides `alloc_store_agent` and `alloc_load_agent`.
Match their geometry parameters to the interface and attach each agent's
`alloc_vif` handle to its store or load endpoint. Instantiate an agent per
endpoint when using multiple contexts.

The store agent exposes `store_req()` and `store()`; the load agent exposes
`load_req()` and `load()`. Both provide `idle()` and `wait_n(cycles)`, and
use sampled clocking-block handshakes. Their transfer methods wait for
completion without an internal deadline; testbench failsafe timeouts bound
stalled tests.

## Verification

The SVUnit suites exercise pointer allocation/recycling, full-pool use, and
duplicate-deallocation detection across representative pointer widths and
parallel slices. Linked-list tests exercise basic store/load requests.
Scatter/gather tests check single- and multi-buffer frame descriptors,
metadata, frame size, and returned buffer chains.

AXI4-Lite suites additionally check software reset, capacity information,
operation counters, and error flags, with register access through an agent.
These suites cover representative configurations rather than every queue
depth, flow-control mode, memory timing, or interface helper.

```sh
# Individual base testbenches (examples)
make -C tests/alloc_bv/
make -C tests/alloc_ll_core/
make -C tests/alloc_sg_core/

# Base regression
make regression

# AXI4-Lite wrapper regression
make -C axil/tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
