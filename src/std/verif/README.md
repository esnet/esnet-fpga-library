# Std Verif

Reusable SystemVerilog classes for transaction-based testbenches, provided
by `std_verif_pkg`. The library supplies component lifecycle management,
mailbox-based dataflow, reference models, scoreboards, and reset-aware
environments. Protocol-specific drivers, monitors, models, and agents extend
these classes. The only library dependency is `std.rtl`.

## Contents

| Component | Description |
|-----------|-------------|
| `base` | Object naming, debug levels, metadata copying, and logging |
| `transaction` | Abstract transaction with copy, clone, comparison, and formatting hooks |
| `raw_transaction` | Transaction carrying a bit vector or packed value |
| `component` | Hierarchical build/reset/init/run/stop lifecycle and locking |
| `agent` | Component with default no-op lifecycle hooks for control interfaces |
| `driver`, `monitor` | Transmit and receive transaction workers |
| `model`, `predictor` | General reference processing and one-input/one-output prediction |
| `sequencer`, `collector` | Expand sequences into transactions and assemble transactions into sequences |
| `scoreboard`, `event_scoreboard` | Comparison accounting and ordered actual/expected matching |
| `raw_model`, `raw_predictor`, `raw_scoreboard` | Convenience classes operating on raw payload values |
| `env`, `basic_env` | Environment lifecycle and DUT reset coordination |
| `component_env`, `component_ctrl_env` | Driver/monitor/model/scoreboard environments, optionally with a control agent |
| `wire_model`, `wire_env` | Pass-through reference model and corresponding environment |

## Transactions and object metadata

`base` provides `get_name()`/`set_name()`, debug-level accessors, and
`trace_msg()`, `debug_msg()`, `info_msg()`, and `error_msg()`. Debug levels
above 0, 1, and 2 enable informational, debug, and trace messages respectively;
error messages are always emitted. `copy()` copies object metadata.

`transaction` adds these subclass hooks:

| Method | Contract |
|--------|----------|
| `to_string()` | Return a printable representation |
| `_copy(transaction)` | Copy subclass payload state |
| `compare(transaction, msg)` | Return true for a match and describe the result in `msg` |

`copy()` copies metadata and invokes `_copy()`. `clone()` returns a new
object with the same dynamic type, then applies `copy()`; its return type is
`transaction`, so cast the result when a concrete transaction handle is needed.

`raw_transaction#(DATA_T)` implements these operations for a raw payload
stored in its public `data` member. `DATA_T` defaults to `bit`; use packed
values such as bit vectors or packed structs. Its constructor accepts a name
and payload, and comparison rejects incompatible transaction types. Static
`from_raw(data, name="raw_transaction")` creates a new transaction; static
`to_raw(transaction)` returns its payload. Call them through the appropriate
specialization, for example `raw_transaction#(bit[31:0])::from_raw(value)`.

```systemverilog
typedef std_verif_pkg::raw_transaction#(bit [31:0]) word_transaction;
word_transaction item = new("request", 32'h12345678);
word_transaction copied;
std_verif_pkg::transaction cloned = item.clone();
void'($cast(copied, cloned));
```

## Component lifecycle

`component` is the abstract base for workers and environments. Subclasses
implement `_build()`, `_reset()`, `_idle()`, `_init()`, and `_run()` as
appropriate; the higher-level worker classes provide most of these hooks.
Register child components with `register_subcomponent()` during construction
or `_build()`.

| Operation | Behavior |
|-----------|----------|
| `build()` | Builds this component and registered children; sets `is_built()` |
| `idle()` | Quiesces children and this component's interfaces |
| `reset()` | Resets local and child state, stopping active processing |
| `init()` | Performs initialization and initializes registered children |
| `run()` | Starts background processing and invokes registered children's `run()` methods |
| `stop()` | Stops this component and registered children |
| `finalize()` | Requests destruction when the component is next stopped |
| `destroy()` | Releases resources and destroys registered children |

Stopping also cancels workers waiting for a manual start; arm them again
with `run()` before restarting. Workers autostart by default. For explicit
start control, call
`disable_autostart()` before `run()`, then `start()` when processing should
begin. `is_running()`, `is_stopped()`, and `is_defunct()` expose lifecycle
state. `lock()` and `unlock()` provide exclusive access for cooperating
clients. Debug-level configuration propagates to registered children.

Configure interfaces and mailboxes before initialization. Stop workers and
allow their background processes to settle before destroying objects or
replacing mailbox handles. Resetting a worker resets its counters; mailbox
flushing is class-specific. In particular, model and scoreboard `init()`
flush stale inputs, so enqueue new traffic after initialization.

## Mailbox workers and subclass hooks

Mailboxes are typed with the transaction parameters. Allocate and connect
mailbox handles before using standalone workers.

| Class | Parameters | Input/output | Implement in a subclass |
|-------|------------|--------------|-------------------------|
| `driver` | `TRANSACTION_T` | `inbox` to interface | `_send(transaction)`, `_idle()` |
| `monitor` | `TRANSACTION_T` | Interface to `outbox` | `_receive(transaction)`, `_idle()` |
| `model` | `TRANSACTION_IN_T`, `TRANSACTION_OUT_T` | `inbox` to `outbox` | `_process(transaction)` |
| `predictor` | `TRANSACTION_IN_T`, `TRANSACTION_OUT_T` | One prediction per input | `predict(transaction)` |
| `sequencer` | `SEQUENCE_T`, `TRANSACTION_T` | One input sequence to multiple output transactions | `_generate(seq)` |
| `collector` | `TRANSACTION_T`, `SEQUENCE_T` | Input transactions to completed sequences | `_process(transaction)` |

Drivers and monitors also expose blocking `send()` and `receive()` methods
for direct use. Their `num_transactions()` counters count completed calls.
Monitors name received transactions with a configurable prefix and sequence
number; use `set_rx_transaction_prefix()` to select the prefix.

Models enqueue results through `_enqueue()` and can account for discarded
transactions with `_drop()`. Predictors implement this processing around
`predict()`. Sequencers call `_enqueue()` for each generated transaction;
collectors call it when a complete sequence is available. Their counter
accessors distinguish input objects from output objects.

`raw_model` and `raw_predictor` default to `byte` input/output payloads.
Implement `_process_raw()` or `predict_raw()` respectively. Raw models also
provide `_enqueue_raw()` to convert and enqueue an output payload. Use the
static `raw_transaction::from_raw()` and `to_raw()` helpers with the input or
output transaction specialization for standalone conversions. The two raw
worker classes extend `model` and `predictor` respectively, specialized with
raw transaction types.

`wire_model` forwards the original input handle. Workers and environment
fanout do not clone transactions automatically; treat shared input objects
as immutable or explicitly clone them before modifying payloads.

## Scoreboards

`scoreboard#(TRANSACTION_T)` provides actual and expected mailboxes named
`got_inbox` and `exp_inbox`, counters, and `report(msg)`. The abstract base
leaves processing and postprocessing policy to subclasses.

`event_scoreboard` consumes one actual transaction and one expected
transaction at a time, in order, and invokes the expected transaction's
`compare()` method. It counts matches and mismatches and treats expected
transactions still queued at final reporting as unmatched. `report(msg)`
returns the mismatch-plus-unmatched count and fills a readable summary.
Call it after processing has stopped and all expected responses have arrived.

`raw_scoreboard#(DATA_T)` specializes the event scoreboard for
`raw_transaction#(DATA_T)`; its payload defaults to `bit [15:0]`.

## Environments

`env` defines DUT-reset hooks and extends `run()` to perform idle, reset,
and initialization before starting background workers.

`basic_env#(RESET_ACTIVE_LOW)` supplies these reset hooks using a virtual
`std_reset_intf`, assigned through `reset_vif`. Reset polarity defaults to
active-high. `set_reset_timeout()` configures readiness timeout in interface
clock cycles; zero means no timeout. `wait_n(cycles)` waits on the reset
interface's clocking block.

`component_env` connects these paths during `build()`:

| Path | Connection |
|------|------------|
| Input | Environment `inbox` fans out to driver and reference model |
| Actual output | Monitor `outbox` feeds scoreboard `got_inbox` |
| Expected output | Model `outbox` feeds scoreboard `exp_inbox` |

Supply concrete driver, monitor, model, and scoreboard types through its type
parameters and instantiate the corresponding public members before `build()`.
`component_ctrl_env` additionally registers its `agent` member.

`wire_env` creates its own `wire_model`; supply concrete driver, monitor, and
scoreboard objects. Both environment families inherit the reset interface
from `basic_env`.

## Verification

The SVUnit suites under `tests/` exercise:

- Transaction metadata, copy/clone independence, dynamic type, comparison,
  formatting, and destruction.
- Hierarchical lifecycle propagation, automatic and manual start, worker
  stop/restart, pending-start cancellation, finalization, and lock exclusion.
- Mailbox ordering, prediction, filtering, sequence expansion/collection,
  driver/monitor counters, and scoreboard matches, mismatches, and unmatched
  expectations.
- Reset polarity and complete loopback environments with and without a
  control agent.

The suite covers both default byte payloads and non-default 32-bit payloads
for raw models/predictors, including direct conversion/prediction and mailbox
processing with different input/output widths. Transaction conversion tests
also check packed structs, naming, and independent allocation.

```sh
# Single testbench
make -C tests/transactions/
make -C tests/lifecycle/
make -C tests/dataflow/
make -C tests/environments/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
