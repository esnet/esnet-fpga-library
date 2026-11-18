# Hash Tables

Key/value hash-table RTL with single-table, parallel multi-table, stash,
and cuckoo insertion implementations. The cores connect application
lookups and updates to externally supplied hash functions and database
storage, with management and register interfaces for table maintenance.

## Contents

| Component | Description |
|-----------|-------------|
| `htable_pkg` | Table types, generic hash type, application insertion modes, and cuckoo key-collision policies |
| `htable_core` | Single-table lookup/update path with stored-key comparison, hash-latency alignment, and optional application forwarding cache |
| `htable_multi_core` | Parallel lookup across tables, per-table management access, and selectable application insertion policy |
| `htable_multi_stash_core` | Parallel tables plus an associative stash populated through its management interface |
| `htable_cuckoo_controller` | Cuckoo insertion/deletion controller, relocation sequencing, operation limits, and register-backed control/statistics |
| `htable_cuckoo_core` | Multi-table lookups combined with cuckoo management and a temporary stash for displaced entries |
| `htable_fast_update_core` | Burst-buffered application insertion/deletion with lookup forwarding while updates are pending |
| `htable_cuckoo_fast_update_core` | Cuckoo table with buffered application updates, management access, and combined register control |
| `htable_verif_pkg` | Cuckoo and fast-update register agents, statistics snapshots, and generated register helpers |

## Application and database interfaces

The library reuses [`db_intf` and `db_ctrl_intf`](../db/README.md) rather
than defining a separate hash-table interface. Refer to the database
library for their complete signal and handshake descriptions.

Application `lookup_if` channels accept a full key and return a value with
validity and error status. Stored keys are compared with the requested key,
so an occupied hash slot containing a different key is a lookup miss.
Application `update_if` channels, where provided, carry a full key, value,
and validity; validity selects insertion or deletion. Supported update
behavior depends on the chosen core and insertion mode.

The `tbl_wr_if` and `tbl_rd_if` ports connect to externally instantiated
database stores. Their keys are table indices, and their values pack the
original key followed by the application value: `{key, value}`. Per-table
`tbl_ctrl_if` management ports use `hash_t` keys and the same packed entry
format, allowing direct access to the underlying slots. Cuckoo `ctrl_if`
ports instead accept full application keys and values and perform the
required hash-table management operations.

`tbl_init` requests storage initialization; `tbl_init_done` reports storage
readiness. `init_done` reports readiness of the complete core. Supply the
stores and connect initialization before issuing application or management
requests. `db_info_intf` reports table type and capacity; variants with
`db_status_intf` also expose occupancy and activity information.

Outstanding requests must fit the configured transaction/context capacity.
Application lookups do not provide physical-entry iteration; use the
management interfaces for storage-level access.

## Hashing and storage

Hash functions are supplied by the consumer. The cores expose the key to
hash and consume the corresponding hash result. Multi-table and cuckoo
variants take a hash for each table, generally using distinct hash
functions to provide alternative entry locations.

| Port family | Direction relative to core | Purpose |
|-------------|----------------------------|---------|
| `lookup_key`, `lookup_hash` | Key out; hash in | Hash the application lookup key for each participating table |
| `update_key`, `update_hash` | Key out; hash in | Hash the application update key on direct-update cores |
| `ctrl_key`, `ctrl_hash` | Keys out; hashes in | Hash keys selected by cuckoo management and relocation |
| Controller `key`, `hash` | Keys out; hashes in | Hashing connection when integrating `htable_cuckoo_controller` separately |

Hashes use the 32-bit `htable_pkg::hash_t` type. Each table uses the low
bits needed for its configured depth. Table depths are intended to be
powers of two. `HASH_LATENCY` describes the supplied hash pipeline latency
in clock cycles; align hash results with the corresponding key stream.
There is no separate ready/valid handshake on the hash ports.

The cores separate table logic from storage implementation. Testbenches
use `db_store_array`; consumers can provide compatible database storage.
`NUM_RD_TRANSACTIONS` and `NUM_WR_TRANSACTIONS`, where available, size
outstanding-transaction tracking. `APP_CACHE_EN` enables forwarding for
closely spaced application accesses to the same underlying slot.

## Insertion policies

A single-table application update writes the selected hash slot. It does
not relocate a different key already occupying that slot. Multi-table
cores select application insertion behavior through `INSERT_MODE`:

| Mode | Behavior |
|------|----------|
| `HTABLE_MULTI_INSERT_MODE_NONE` | Application writes are disabled; management supplies entries |
| `HTABLE_MULTI_INSERT_MODE_ROUND_ROBIN` | Successive application writes select successive tables |
| `HTABLE_MULTI_INSERT_MODE_BROADCAST` | Each application write is sent to every table |

These modes select write destinations; they do not implement cuckoo
relocation or remove duplicate keys from other tables. Avoid conflicting
copies of a key when managing tables directly. The multi-table stash is
managed separately: application writes do not automatically spill into it.

Cuckoo management searches the candidate locations and moves displaced
entries between tables. A temporary bubble stash keeps displaced entries
available to lookups during relocation. Register configuration controls
the operation limit; collision policy selects whether an existing key can
be overwritten or is reported as an insertion error.

The fast-update layer buffers insertion/deletion bursts in a pending-update
stash, applies them to the managed table, and forwards pending results to
lookups. `UPDATE_BURST_SIZE` sets its buffering capacity. Readiness provides
backpressure when that capacity is exhausted.

RTL dependencies include the database library and its FIFO, memory,
register, and utility support. Control registers are generated from
`regio/` definitions.

## Verification components

`htable_cuckoo_reg_agent` and `htable_fast_update_reg_agent` provide reset,
readiness polling, information queries, and latched operation statistics.
The cuckoo agent also configures relocation limits. `stats_t` represents
insertion/deletion success and failure counts plus active entries.

Testbenches use database agents for direct table management and application
traffic, AXI4-Lite agents for register access, and reference key/value
collections for result checking.

## Verification

The SVUnit suites exercise single-table and parallel-table access,
separately managed stash lookups, cuckoo insertion and relocation, and
buffered application updates. Directed and randomized checks cover
management reads/writes, insertion/deletion/replacement, lookup misses,
colliding keys, table occupancy, register statistics, reset, and update
bursts. Round-robin checks cover destination distribution and reset with
non-power-of-two table counts. The cuckoo suite checks lookup visibility
during ongoing relocation.
Individual testbenches define their configurations and detailed coverage.

```sh
# Single testbench
make -C tests/htable_core/

# Full regression
make -C tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
