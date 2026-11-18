# Mem Proxy

Register-controlled access to a memory through AXI4-Lite. `mem_proxy`
translates command and data-window registers into transactions on the
combined `mem_intf` interface. It includes clock-domain crossing between
the AXI4-Lite and memory clocks, plus a verification agent for register-based
memory access.

## Contents

| Component | Description |
|-----------|-------------|
| `mem_proxy` | AXI4-Lite command engine for memory reads, writes, and reset requests |
| `mem_proxy.yaml` | Register-map source for generated RTL and verification accessors |
| `mem_proxy_agent` | Verification agent for memory commands, byte-array transfers, and information queries |
| `mem_proxy_protocol.py` | Regio indirect-access protocol for single-word software reads and writes |

`mem.proxy.rtl` depends on `mem.rtl`, `mem.proxy.regio.rtl`, `axi4l.rtl`, and
`std.rtl`. `mem.proxy.verif` depends on `mem.rtl`, `mem.proxy.regio.verif`,
`reg.verif`, and `string.pkg`. The register components are generated from
[the YAML specification](regio/mem_proxy.yaml).

## RTL configuration

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `ACCESS_TYPE` | `ACCESS_UNSPECIFIED` | Access classification reported through the information registers |
| `MEM_TYPE` | `MEM_TYPE_UNSPECIFIED` | Memory classification reported through the information registers |
| `TIMEOUT_CYCLES` | `1000` | Cycle limit for read/write request and completion processing |
| `BIGENDIAN` | `0` | Reverse byte ordering within each memory word when nonzero |

The classifications come from `mem_pkg`; they describe the attached memory.
`ACCESS_TYPE` does not enforce write protection in the command engine.
Address and data widths are taken from `mem_if`.

| Port | Role |
|------|------|
| `clk`, `srst` | Memory/control clock and active-high synchronous reset |
| `init_done` | Initial memory reset/readiness sequence has completed |
| `axil_if` | AXI4-Lite peripheral interface, with its own clock and reset |
| `mem_if` | Combined memory controller interface, clocked by `clk` |

The internal AXI4-Lite bridge crosses register accesses into `clk`.
Initialization and `CLEAR` assert `mem_if.rst`, then wait for the memory to
become ready. Actual clearing depends on the attached peripheral's reset
behavior; a RAM wrapper needs reset-FSM initialization enabled to clear its
contents. Wait for initialization before issuing memory commands.

## Commands and register window

The register block exposes:

| Register group | Purpose |
|----------------|---------|
| `info`, `info_depth`, `info_size_*`, `info_burst` | Type, access classification, word size/depth, byte capacity, and burst limits |
| `control`, `monitor` | Software reset and block state/readiness monitoring |
| `addr`, `burst` | Starting memory word address and transaction length in words |
| `wr_data[16]` | Sixteen 32-bit write-data registers |
| `rd_data[16]` | Sixteen 32-bit read-data registers |
| `command` | Starts `NOP`, `READ`, `WRITE`, or `CLEAR` |
| `status` | Ready/busy/reset state, completion/error/timeout flags, and completed byte count |

`addr` is a **word address**, rather than a byte offset. A burst increments
the memory address for each word. `burst.len=0` is treated as one word.
The byte size of a word is `ceil(DATA_WID/8)`. For byte-aligned word widths,
the maximum burst length is `64 / DATA_BYTES` words, using the 64-byte data
window. Non-byte-aligned widths are limited to a single word. Choose a
width that fits the window and issue lengths within the reported limits.

A typical operation is:

1. Wait for `status.code` to report ready.
2. Set `addr` and `burst.len`; for writes, populate `wr_data`.
3. Write the command code to `command`.
4. Poll `status` for completion, error, or timeout.
5. For reads, collect the valid bytes from `rd_data`.

Completion flags remain set until status is read or a new transaction
starts. A successful transfer reports its byte count in `status.burst_size`.
Only one command should be outstanding through this register interface.
`NOP` completes without a memory access. `CLEAR` requests a peripheral reset;
its completion wait is separate from the read/write timeout mechanism.

Within the register window, byte 0 occupies bits 7:0 of data register 0.
With `BIGENDIAN=0`, this maps to the least significant byte of memory word 0.
With `BIGENDIAN` enabled, byte order reverses within each memory word while
word address order remains unchanged.

## Verification agent and software protocol

`mem_proxy_verif_pkg::mem_proxy_agent` extends the generated register-block
agent. Construct it with a name, memory data width, a `reg_agent` transport,
and an optional register base offset. An `axi4l_reg_agent` can provide the
transport for the RTL proxy.

| Method | Purpose |
|--------|---------|
| `wait_ready()` | Poll until initialization or the current operation completes |
| `nop()`, `clear_all()`, `transact()` | Issue commands and report errors/timeouts |
| `write(addr, data, error, timeout)` | Write a byte array starting at a memory word address |
| `read(addr, size, data, error, timeout)` | Read a byte count starting at a memory word address |
| `get_type()`, `get_access()`, `get_alignment()`, `get_depth()`, `get_size()` | Query the attached memory description |
| `get_min_burst_size()`, `get_max_burst_size()` | Query supported burst byte sizes |
| `get_data_wid()`, `get_data_byte_wid()`, `get_max_burst_len()`, `get_window_size()` | Inspect the agent's configured transfer geometry |
| `set_reset_timeout()`, `set_op_timeout()` | Configure reset and operation wait limits |

The agent splits large byte arrays into window-sized commands and advances
the word address between them. Partial final writes are padded with zeroes
to the next whole memory word; they do not preserve the other bytes of that
word. Byte arrays follow the register window's ordering. Timeout defaults
are unlimited for reset and 128 transport wait cycles for other operations.

The Python Regio protocol performs single-word indirect reads and writes
through the same register map. It polls readiness/completion and raises
exceptions for errors, timeouts, and unexpected transfer sizes. Its offsets
are memory word addresses.

## Verification

The SVUnit suite exercises register-controlled memory access through an
AXI4-Lite agent and a RAM model with reset initialization. It checks
readiness, memory information, command completion, and randomized data
readback, including transfers split across multiple register-window
commands. Separate AXI4-Lite and memory clocks exercise the clock-domain
crossing path.

The current suite uses the default byte ordering and a read/write SRAM
configuration. Reversed byte ordering, injected errors/timeouts, and the
Python protocol are outside its coverage.

```sh
# Single testbench
make -C tests/mem_proxy/

# All tests
make -C tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
