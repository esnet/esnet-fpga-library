# FIFO AXI4-Lite

FIFO wrappers with AXI4-Lite software reset, configuration information, and
write/read monitoring registers. `fifo.axil.rtl` depends on `fifo.rtl`,
`fifo.regio.rtl`, `axi4l.rtl`, and `sync.rtl`.

## Contents

| Module | Description |
|--------|-------------|
| `fifo_axil_sync` | Single-clock FIFO with register control and monitoring |
| `fifo_axil_async` | FIFO with independent write/read clocks and register access |
| `fifo_axil_core` | Shared FIFO, address decoder, register blocks, and clock-domain crossings |

## FIFO data path

The wrappers retain the data-path behavior of the corresponding
[`fifo`](../README.md) components. AXI4-Lite provides control and monitoring;
words enter and leave through the dedicated write/read ports.

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `DATA_WID` | `1` | Stored word width |
| `DEPTH` | `32` | Main FIFO storage depth |
| `FWFT` | `1` | Enable first-word fall-through output buffering |
| `OFLOW_PROT` | `1` | Protect against writes to full storage |
| `UFLOW_PROT` | `1` | Protect against reads from empty storage |
| `CNT_WID` | Derived | Occupancy counter width; do not override |

`fifo_axil_sync` uses `clk` and synchronous active-high `srst`.
`fifo_axil_async` uses separate `wr_clk`/`wr_srst` and `rd_clk`/`rd_srst`.
The shared core selects the clocking arrangement with `ASYNC`, defaulting
to `1`.

Assert `wr` with `wr_data` to write, observing `wr_rdy` and full status.
With `FWFT=0`, `rd` requests a word and `rd_ack` qualifies the returned data.
With `FWFT=1`, `rd_ack` qualifies the current output word and `rd` consumes
it. See the parent FIFO README for capacity, protection, and occupancy
semantics.

## Register control and monitoring

Connect `axil_if` to an AXI4-Lite controller. Its clock can be independent of
both FIFO clocks. The decoder exposes the following byte offsets relative
to the FIFO register base:

| Offset | Register block | Capability |
|--------|----------------|------------|
| `0x000` | `fifo_ctrl` | FIFO type, protection settings, FWFT mode, depth, width, and software reset |
| `0x040` | `fifo_wr_mon` | Write-domain reset, full/overflow state, occupancy, and write pointer |
| `0x080` | `fifo_rd_mon` | Read-domain reset, empty/underflow state, occupancy, and read pointer |

Register definitions are maintained under [`fifo/regio`](../regio/).
Monitoring registers sample their local FIFO state through pipelined
monitoring interfaces. AXI4-Lite transactions cross into the corresponding
FIFO clock domain, so register reads have crossing and transport latency.
Separate status reads do not form an atomic snapshot of both domains.

The control register's reset bit is synchronized into the write domain and
combined with `wr_srst`; the asynchronous FIFO propagates reset to the
read side. Software must assert and then clear this bit, and allow FIFO
readiness to settle before resuming traffic. Reset discards queued data.

`fifo_verif_pkg::fifo_reg_agent`, provided by `fifo.verif`, accesses these
registers through a register-agent transport and an optional base offset.
It provides FIFO information queries, count/pointer and full/empty queries,
and a `soft_reset()` helper that asserts and clears the reset bit.

## Verification

The SVUnit suite exercises the asynchronous wrapper through AXI4-Lite and
bus verification agents. It checks configuration information, software
reset, monitored occupancy and pointers, ordered data readback, empty/full
boundaries, and overflow protection. Representative configurations include
standard and FWFT reads, non-power-of-two depths, and traffic with faster
write or faster read clocks.

The synchronous wrapper has no dedicated suite here; its underlying FIFO
data path is exercised by the parent library's synchronous FIFO tests.

```sh
# Individual testbench
make -C tests/fifo_axil_async/

# All tests
make -C tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
