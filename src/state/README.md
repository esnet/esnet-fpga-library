# State

Stateful read/modify/write components for per-ID counters, flags, sampled
values, sequences, and composite state vectors. The library combines
configurable update operations with database storage, management access,
key-to-ID tracking, and state scanning/notification.

## Contents

| Component | Description |
|-----------|-------------|
| `state_pkg` | Element/vector specifications, operation contexts, return/reap policies, and expiry messages |
| `state_element` | Configurable state transformation with previous-state input, update input, next-state output, and a selected return value |
| `state_vector` | Parallel composition of state elements using a packed state/update layout |
| `state_element_core` | Per-ID state storage access and read/modify/write control for one element |
| `state_vector_core` | Per-ID vector updates, datapath/control arbitration, database management, and optional forwarding cache |
| `state_core` | State-vector core with register-controlled scanning and notifications |
| `state_intf` | State request/completion signals, clocking block, connectors, tie-offs, proxy, and datapath/control mux |
| `state_check_intf` | State evaluation request with active/notify/message response |
| `state_event_intf` | Unbackpressured notification feed carrying an ID and message |
| `state_notify_fsm` | Database scanner that invokes an application-specific state check and publishes notifications |
| `state_cache_core` | Hash-table-backed key tracking, ID allocation/reclamation, and key/ID deletion paths |
| `state_id_manager` | ID allocation/deallocation and reverse ID-to-key storage for deletion |
| `state_histogram_core` | Combinational per-bin update strobes for inclusive data ranges; counters are supplied externally |
| `state_verif_pkg` | Typed transactions, interface agents, drivers/monitors, reference models, and register agents |
| `state.tb` | Shared test environment connecting state agents, database agents, reset, and reference models |

## State elements and vectors

An `element_t` specification selects the element type, state and update
widths, return mode, and reap mode. Supported operations include reads,
unconditional and conditional writes, write-if-zero and limited-write
sampling, flag accumulation, event/conditional counters, weighted counts,
and sequence tracking. Update layouts depend on the element type; consult
the corresponding RTL and tests when constructing updates.

Operation context distinguishes datapath updates, control updates, reaping,
and no-op requests. These contexts can apply different transformations to
the same stored state. For example, a read element leaves state unchanged
on datapath access but accepts writes from the control path. Reap modes clear
state, preserve it, or apply the control transformation.

Return modes select the previous state, the updated state, or their delta.
State arithmetic is bounded by the configured field widths. `init` selects
the element's initialization behavior for an update; it is separate from
module reset and database initialization.

A `vector_t` specification combines element definitions. Element zero
occupies the least-significant state bits; successive elements follow in
specification order. Update fields use the same ordering, omitting fields
whose configured update width is zero. Package helpers calculate aggregate
widths and offsets. Interfaces retain a minimum update width of one bit
when no element consumes update data.

## `state_intf`

The interface carries a per-ID operation followed by its returned state.
Directions below are relative to the source (`source` modport).

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ID_WID` | `1` | State ID width in bits |
| `STATE_WID` | `1` | Returned state width in bits |
| `UPDATE_WID` | `1` | Update data width in bits |

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | in | 1 | Interface clock; transfers are sampled on rising edges |
| `req` | out | 1 | Operation request is valid |
| `rdy` | in | 1 | Target can accept the request |
| `ctxt` | out | 2 (`update_ctxt_t`) | No-op, datapath, control, or reap context |
| `id` | out | `ID_WID` | State entry to access |
| `init` | out | 1 | Select initialization behavior for an update |
| `update` | out | `UPDATE_WID` | Element-specific update data |
| `ack` | in | 1 | Completion of an accepted operation |
| `state` | in | `STATE_WID` | Returned state selected by the element/vector specification |

A request is accepted when `req && rdy` is true on a rising edge. Hold
request fields stable until acceptance. Completion is reported by `ack`,
which qualifies `state`; there is no response-ready signal or transaction
ID. Size the configured outstanding-transaction capacity for the connected
source and storage latency.

The interface provides `source` and `target` modports and a rising-edge
`cb` clocking block with implicit default skews. `cb.mon_req` samples the
driven request independently of its output clockvar. Reset is supplied
separately to the connected modules. Timed request/response helpers live in
`state_intf_agent`; split request and response methods allow pipelined
stimulus. Its response timeout bounds acknowledgement waiting after request
acceptance; readiness has a separate timeout helper.

## Check and notification interfaces

`state_check_intf` connects the scanner to application-specific state
classification logic. Its `STATE_WID` and `MSG_WID` parameters both default
to one bit. Directions are relative to the check source (`source` modport).

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | in | 1 | Check-interface clock |
| `req` | out | 1 | State evaluation request |
| `state` | out | `STATE_WID` | State value to evaluate |
| `ack` | in | 1 | Evaluation response is valid |
| `active` | in | 1 | Entry is classified as active |
| `notify` | in | 1 | Publish a notification for this entry |
| `msg` | in | `MSG_WID` | Application-defined notification payload |

There is no request-ready or response-ready signal. The supplied scanner
issues a check and waits for its acknowledgement before proceeding. Its
registered state value remains available while the check is pending.
Classification logic supplies the response fields with `ack`; the scanner
does not prescribe the application's expiry or activity policy.

`state_event_intf` publishes the resulting ID/message pair. `ID_WID` and
`MSG_WID` both default to one bit. Directions below are relative to the
publisher (`publisher` modport).

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | in | 1 | Notification clock |
| `evt` | out | 1 | Notification is valid on this rising edge |
| `id` | out | `ID_WID` | ID associated with the notification |
| `msg` | out | `MSG_WID` | Notification payload |

The subscriber must accept each cycle qualified by `evt`; there is no
backpressure or acknowledgement. Expiry message definitions are provided
in `state_pkg`, while consumers may select their own message layout.
Both interfaces provide clocking blocks with implicit default skews;
`state_check_agent` and `state_event_agent` provide active verification
helpers.

## Storage and integration

The state cores expose database initialization and read/write interfaces
for externally instantiated storage. [`db_intf` and `db_ctrl_intf`](../db/README.md)
provide storage access and direct management operations. Use database keys
as state IDs and database values as packed state vectors. Connect storage
readiness before issuing updates.

Datapath updates take priority over control requests in the shared state
mux. `CACHE_EN` enables forwarding for closely spaced operations on the
same state ID; disabling it requires the application to tolerate the
resulting storage consistency limits. Transaction-depth parameters size
request context tracking.

The notification scanner accesses state through the database control path
and invokes external check logic. Register agents configure scanning and
read scanner status/statistics. The cache and ID-manager components combine
hash-table lookup, buffered updates, ID allocation, and reverse mappings;
consumers supply hash functions and table storage through their ports.

RTL dependencies include the database, hash-table, allocator, FIFO,
register, and utility libraries. Register definitions are generated from
`regio/`. The `build/state_vector_sram` example connects a state vector to
memory-backed storage.

## Verification

The SVUnit suites combine state element/vector reference models with
directed and randomized checks. Coverage includes datapath and control
updates, initialization, return/reap behavior, repeated-ID accesses,
sequences, composite vectors, database management, scanning/notifications,
and key-to-ID cache insertion/deletion and reclamation. Interface-agent
checks cover operation contexts, response timeouts, check payloads,
notification pulses, and typed driver/monitor transfers. Individual tests
define detailed specifications and configurations.

`state_req` and `state_resp` represent typed updates and returned state.
Drivers/monitors support transaction streams; interface agents support
directed stimulus. Register agents expose state, cache, and notification
control and reporting. The shared test environment connects these helpers
to reset, storage management, and reference models.

```sh
# Single testbench
make -C tests/state_element_core/

# Full regression
make -C tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
