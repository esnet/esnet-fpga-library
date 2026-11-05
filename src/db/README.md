# Database

Key/value database interfaces, storage components, control logic, and
verification agents. The library separates application query/update traffic
from management commands so that storage implementations can share a common
control and register-access path.

## Contents

| Component | Description |
|-----------|-------------|
| `db_pkg` | Database types, stash subtypes, management commands, and response status codes |
| `db_intf` | Application/storage request and response interface, with connectors, tie-offs, and read/write multiplexers |
| `db_ctrl_intf` | Management command interface, with connectors, a proxy stage, static multiplexers, and priority arbitration |
| `db_info_intf` | Database type, subtype, and capacity reporting |
| `db_status_intf` | Occupancy, full/empty status, and activation/deactivation event counters |
| `db_core` | Shared application and management access to a database store, with transaction tracking and optional forwarding caches |
| `db_peripheral` | Management command execution against a store, including initialization, iteration, and optional operation timeouts |
| `db_axil_ctrl` | AXI4-Lite register access to database commands, information, and status |
| `db_store_array` | Direct-indexed, memory-backed storage with optional per-entry validity tracking |
| `db_store_lru` | Associative storage with least-recently-used replacement and optional write-through behavior |
| `db_stash` | Associative stash that updates matching keys, inserts into free slots, and reports insertion failure when full |
| `db_stash_lru` | Database wrapper around least-recently-used storage |
| `db_stash_fifo` | Associative stash with FIFO entry ordering and head-based iteration/removal |
| `db_verif_pkg` | Typed transactions, application and management agents, drivers/monitors, reference model, and scoreboard |

## `db_intf`

The application/storage interface uses a request/ready handshake followed
by a completion acknowledgement. The same interface represents a query
(read) channel or an update (write) channel.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `KEY_WID` | `1` | Key width in bits |
| `VALUE_WID` | `1` | Value width in bits |

Directions below are relative to the requester (`requester` modport).

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | in | 1 | Transfer clock; requests and responses are sampled on rising edges |
| `req` | out | 1 | Request is valid |
| `rdy` | in | 1 | Responder can accept a request |
| `key` | out | `KEY_WID` | Key to query or update when `next=0` |
| `next` | out | 1 | Access the next physical storage entry instead of selecting by `key` |
| `ack` | in | 1 | Completion of an accepted request |
| `error` | in | 1 | Operation failed; qualified by `ack` |
| `valid` | in for reads; out for writes | 1 | Read result validity, or validity to install with a write |
| `value` | in for reads; out for writes | `VALUE_WID` | Read result, or value to install with a write |
| `next_key` | in | `KEY_WID` | Key returned for an iteration request; qualified by `ack` and `valid` |

A request is accepted when `req && rdy` is true on a rising edge. Hold
`req`, `key`, `next`, and any write validity/value stable until acceptance.
The responder later asserts `ack` with the completion status and any read
result. There is no response-ready signal, so the requester must accept
completions as they arrive. Outstanding requests must fit the transaction
capacity of the connected components; the interface has no transaction ID.

For reads, `valid=0` reports an absent or invalid entry and the returned
value is unqualified. For writes, `valid=1` installs a value and `valid=0`
removes an entry. An unsuccessful operation is indicated by `error`;
an ordinary lookup miss is represented by read validity. Iteration can
visit invalid physical entries, and its ordering and support depend on
the storage implementation.

The `requester` and `responder` modports declare validity and value as
`inout` because their direction depends on the channel's purpose. Select
the matching read or write connector/multiplexer so that these fields flow
in the correct direction. These are directional payload signals rather
than a bidirectional shared bus.

The `cb` clocking block uses rising edges of `clk` and implicit default
skews. `cb.mon_req` samples the driven request independently of its output
clockvar. Reset is supplied separately to the connected modules. Timed
request/response helpers live in `db_intf_agent`, `db_driver`, and
`db_monitor`.

## `db_ctrl_intf`

The management interface carries database commands independently of
application traffic. It has the same `KEY_WID` and `VALUE_WID` parameters
and defaults as `db_intf`. Directions below are relative to the controller
(`controller` modport).

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | in | 1 | Transfer clock; commands and completions are sampled on rising edges |
| `req` | out | 1 | Command request is valid |
| `rdy` | in | 1 | Peripheral can accept a command |
| `command` | out | 3 (`db_pkg::command_t`) | Operation to perform |
| `key` | out | `KEY_WID` | Key for a keyed operation |
| `set_value` | out | `VALUE_WID` | New value for set or replace |
| `ack` | in | 1 | Command completion |
| `status` | in | 2 (`db_pkg::status_t`) | Completion status, qualified by `ack` |
| `get_valid` | in | 1 | Returned entry validity for a command that reads an entry |
| `get_key` | in | `KEY_WID` | Returned key for an iteration command |
| `get_value` | in | `VALUE_WID` | Returned value, qualified by `ack` and `get_valid` |

Hold the command and its operands stable while `req` is asserted until
`req && rdy` accepts it. Completion is reported with `ack`; there is no
response backpressure. The supplied `db_peripheral` executes one command
at a time and deasserts readiness while busy. A controller waits for its
completion before issuing the next command.

| Command | Operation |
|---------|-----------|
| `COMMAND_NOP` | Complete a command handshake without changing storage |
| `COMMAND_GET` | Read the entry selected by `key` |
| `COMMAND_GET_NEXT` | Read the next physical entry and return its key |
| `COMMAND_SET` | Write a valid entry using `key` and `set_value` |
| `COMMAND_UNSET` | Invalidate the selected entry and return its previous validity/value |
| `COMMAND_UNSET_NEXT` | Invalidate the next physical entry and return its previous key/validity/value |
| `COMMAND_REPLACE` | Write `set_value` at `key` and return the previous validity/value |
| `COMMAND_CLEAR` | Initialize/clear the database |

`STATUS_OK` indicates successful completion, `STATUS_ERROR` indicates an
operation error, and `STATUS_TIMEOUT` indicates that the peripheral's
configured operation deadline expired. `STATUS_UNSPECIFIED` is not a
successful completion status. Returned entry fields are meaningful only
for commands that read an entry; an invalid entry does not by itself
indicate a command error.

The interface provides `controller` and `peripheral` modports and a `cb`
clocking block with rising-edge sampling and implicit default skews.
Reset is supplied separately to the connected modules. `db_ctrl_agent`
provides timed command helpers; connector, proxy, and mux modules provide
RTL routing and arbitration.

## Information and status interfaces

`db_info_intf` reports database `_type`, `subtype`, and 32-bit entry
capacity `size`. The peripheral supplies these fields and the controller
observes them. There is no clock or transaction handshake; these fields
describe the connected storage.

`db_status_intf` uses `clk` and active-high synchronous `srst`. The
peripheral supplies 32-bit `fill`, single-bit `empty`/`full` levels, and
activation and deactivation event indications. The interface counts those
events and exposes `cnt_activate`, `cnt_deactivate`, and `cnt_active` to the
controller. Status is observed continuously without backpressure. Counters
initialize to zero and clear on reset.

Each asserted event cycle increments its corresponding total. The current
`cnt_active` implementation gives deactivation priority if both event
signals assert together, so producers must avoid simultaneous activation
and deactivation when relying on that count. Status and information
interfaces do not provide clock-domain crossing.

## Storage and integration

Storage policy determines key interpretation, capacity behavior, and
iteration order. Array storage uses the key as an address; associative
stores compare complete keys. LRU storage can select read-first or
write-through behavior for simultaneous access to the same key. Consult
individual modules when selecting concurrency and forwarding policies.

RTL dependencies include the standard, utility, FIFO, memory, and register
libraries. Register definitions and access helpers are generated from
`regio/db.yaml`.

## Verification components

`db_intf_agent` provides clocking-block-based application queries, updates,
posted updates, and readiness waits. `db_driver` and `db_monitor` support
transaction-stream stimulus and response collection.

`db_ctrl_agent` performs management operations through `db_ctrl_intf`;
`db_reg_agent` exposes the same database operations through a register
agent. Both extend `db_agent`, which provides command helpers and configurable
operation/reset timeouts. Information and status interfaces provide database
identity, capacity, occupancy, and event counters.

Request/response transactions, `db_model`, and `db_scoreboard` provide typed
reference-model and comparison support. Verification dependencies include
`std.verif` and register verification helpers.

## Verification

The SVUnit suites exercise database control interfaces and routing,
management commands, application reads/writes, and stash storage policies.
Directed and randomized checks cover key/value access, validity, replacement,
iteration, capacity, and concurrent application/control traffic. Control
multiplexer tests include backpressure and priority routing. Application-agent
checks cover pipelined responses, bounded transfers, error responses, and
timeout recovery.

```sh
# Single testbench
make -C tests/db_stash/

# Full regression
make -C tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
