# MY_COMPONENT_NAME

Describe the component's purpose, main capabilities, and dependencies.

## Contents

| Component | Description |
|-----------|-------------|
| `MY_COMPONENT_MODULE` | Describe the provided module, interface, package, or agent |

## Interface and operation

Describe the important interface contracts: clock and reset, signal
directions, transfer acceptance/completion, backpressure, payload stability,
address or byte ordering, and packet/transaction boundaries where relevant.
Explain configuration parameters and integration constraints. Link to a
shared interface guide when the component reuses an existing protocol.

## Verification

Summarize the test capability and representative configurations at a high
level. Describe relevant coverage limits; leave test counts and detailed
case lists to the testbenches. Omit unsupported commands and adapt the
paths below to the actual test layout.

```sh
# Individual testbench
make -C tests/MY_COMPONENT_MODULE/

# All tests (when provided by the component Makefile)
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
Simulator setup and selection follow the enclosing repository's test
procedure. Document component-specific restrictions here.
