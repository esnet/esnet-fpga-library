# Arb

Configurable strict-priority and round-robin arbiters with one-hot grants,
binary selectors, and acknowledgement-based support for multi-cycle ownership.

## Contents

| Component | Description |
|-----------|-------------|
| `arb_pkg` | Package defining the `arb_rr_mode_t` enumeration (`RR`, `WCRR`) |
| `arb_prio` | Strict-priority arbiter; the lowest requesting index wins |
| `arb_rr` | Round-robin arbiter with optional work-conserving scheduling |

## Interface and handshake

Both arbiters share the following interface:

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` | in | Clock; state updates on the rising edge |
| `srst` | in | Active-high synchronous reset; clears arbitration state |
| `en` | in | Enables new arbitration decisions |
| `req[N-1:0]` | in | One request bit per client |
| `grant[N-1:0]` | out | One-hot grant, or zero when no client is granted |
| `ack[N-1:0]` | in | Acknowledgement from each client; only the selected client's bit is used |
| `sel` | out | Binary index of the selected client; meaningful for a transfer when `grant` is nonzero |

Grants are combinational. If a grant is sampled on a rising edge with its
acknowledgement asserted, arbitration can continue on the next cycle. If the
acknowledgement is low, the arbiter retains that grant and selector until the
selected client acknowledges on a subsequent rising edge. The client may drop
its request while the grant is held.

`en=0` suppresses new grants and pauses round-robin advancement. An existing
held grant remains asserted even when `en=0`; acknowledgement can still release
it. Reset cancels a held grant. Following reset, the state machine enters its
grant state on the first rising edge with `srst=0`.

## Modules

### `arb_prio` — Strict priority

| Parameter | Default | Description |
|-----------|---------|-------------|
| `N` | `2` | Number of clients; use `N >= 2` |

Client 0 has the highest priority and client `N-1` the lowest. When several
requests are active, the lowest index wins. A held grant takes precedence over
new requests, including requests from higher-priority clients. Persistent
higher-priority traffic can starve lower-priority clients.

`sel` is an `integer` and is not gated by `en`. With no requests and no held
grant, it defaults to zero.

### `arb_rr` — Round robin

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MODE` | `arb_pkg::RR` | Arbitration policy (`RR` or `WCRR`) |
| `N` | `2` | Number of clients; `N >= 1` |
| `SEL_WID` | `N > 1 ? $clog2(N) : 1` | Derived selector width; do not override |

The selector resets to zero. During enabled arbitration with at least one
request, the next search starts after the previously registered selector and
wraps at `N-1`.

- **`RR`** advances one client position at a time. If that client is not
  requesting, the cycle has no grant even when another client is requesting.
- **`WCRR`** scans past inactive clients in the same cycle, granting an active
  requester whenever any request is present and arbitration is enabled.

Both modes retain the current selection while a grant awaits acknowledgement.
When all requests are low or `en=0`, the selector retains its registered value.
For example, with all four clients continuously requesting and acknowledging,
the grant order after reset is 1, 2, 3, 0, then repeats.

## Verification

SVUnit tests exercise both arbiters with four clients, including both `RR`
and `WCRR` modes. They check grant and selector values, immediate and delayed
acknowledgements, and grant retention after request withdrawal. Round-robin
tests also cover randomized concurrent requests and cyclic grant order under
persistent requests.

Unit tests live under `tests/` and can be run individually or as a regression:

```sh
# Single testbench
make -C tests/arb_prio/
make -C tests/arb_rr/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
