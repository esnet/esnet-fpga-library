# CRC

Parallel and serial hardware CRC engines, configurable to any standard CRC
algorithm.  All modules share a common configuration interface defined in
`crc_pkg` and use the same data-bus byte-order convention.

## Contents

| Component | Description |
|-----------|-------------|
| `crc_pkg` | Package: config struct, algorithm functions, predefined CRC specs |
| `crc` | Stateless parallel CRC — one result per enabled clock cycle |
| `crc_accum` | Accumulating parallel CRC — stateful, multi-beat packets with partial-beat support |
| `crc_verif_pkg` | Verification package: software reference model matching the RTL |

---

## Algorithm Configuration (`crc_pkg`)

Every module is parameterised with a `crc_config_t` struct:

```systemverilog
typedef struct {
    int   WIDTH;    // CRC width in bits (8, 16, 24, or 32)
    CRC_T POLY;     // Generator polynomial (normal / non-reflected form)
    CRC_T INIT;     // Initial value of the CRC state register
    int   REFIN;    // 1 = reflect each input byte's bits before processing
    int   REFOUT;   // 1 = reflect the CRC register before XOROUT
    CRC_T XOROUT;   // Final XOR mask applied to the (possibly reflected) CRC
    CRC_T CHECK;    // Expected CRC of the ASCII string "123456789" (self-test)
    CRC_T RESIDUE;  // Expected CRC register value after appending a correct FCS
} crc_config_t;
```

These fields follow the standard CRC catalogue definition at
<https://reveng.sourceforge.io/crc-catalogue/all.htm>.

### Predefined specifications

`crc_pkg` provides `crc_spec_t` constants for common algorithms.  Pass the
`.cfg` field as the `CONFIG` parameter:

| Constant | Algorithm | REFIN | REFOUT | Typical use |
|----------|-----------|-------|--------|-------------|
| `CRC32` / `CRC32_ISO_HDLC` / `CRC32_V42` | CRC-32/ISO-HDLC | 1 | 1 | Ethernet FCS, ZIP |
| `CRC32_ISCSI` / `CRC32_INTERLAKEN` / `CRC32_C` | CRC-32C | 1 | 1 | iSCSI, hardware-accelerated |
| `CRC32_AUTOSAR` | CRC-32/AUTOSAR | 1 | 1 | Automotive |
| `CRC32_BZIP2` / `CRC32_AAL5` | CRC-32/BZIP-2 | 0 | 0 | ATM AAL5 |
| `CRC32_CKSUM` / `CRC32_POSIX` | CRC-32/POSIX | 0 | 0 | POSIX `cksum` |
| `CRC16_KERMIT` / `CRC16_CCITT` | CRC-16/KERMIT | 1 | 1 | — |
| `CRC16_USB` | CRC-16/USB | 1 | 1 | — |
| `CRC16_XMODEM` / `CRC16_LTE` | CRC-16/XMODEM | 0 | 0 | — |
| `CRC16_CDMA2000` | CRC-16/CDMA2000 | 0 | 0 | — |
| `CRC8_SMBUS` / `CRC8` | CRC-8/SMBUS | 0 | 0 | — |
| `CRC24_INTERLAKEN` | CRC-24/INTERLAKEN | 0 | 0 | Interlaken |

`DEFAULT_CRC` is `CRC32` (CRC-32/ISO-HDLC, the standard Ethernet FCS).

---

## Data Bus Convention

All parallel modules use the port declaration:

```systemverilog
input logic [0:DATA_BYTES-1][7:0] data
```

**`data[0]` is the first byte of the message** (network / big-endian byte
order).  `data[DATA_BYTES-1]` is the last byte processed in a full beat.

This byte-order convention is independent of the REFIN/REFOUT algorithm
parameters, which control *bit* reflection within each byte and within the
final CRC register, respectively.  For example, Ethernet CRC-32 (REFIN=1,
REFOUT=1) still receives `data[0]` as the first frame byte; each byte's bits
are reflected before entering the GF(2) shift register, and the completed
register is bit-reflected before XOROUT is applied.

---

## Modules

### `crc` — Stateless Parallel CRC

Computes a fresh CRC from `CONFIG.INIT` over the full `DATA_BYTES`-wide data
word on every enabled cycle.  The result is registered.

```
Parameter     Default            Description
CONFIG        DEFAULT_CRC.cfg    CRC algorithm configuration
DATA_BYTES    1                  Width of the data bus, in bytes
```

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` | in | Clock |
| `srst` | in | Synchronous reset — clears output register |
| `en` | in | Enable — captures new CRC on rising edge |
| `data[0:DATA_BYTES-1][7:0]` | in | Input data (byte 0 = first byte of message) |
| `crc[WIDTH-1:0]` | out | Registered CRC result |

Each `en` pulse is independent; the module does not accumulate state across
beats.  Use `crc_accum` for multi-beat packets.

---

### `crc_accum` — Accumulating Parallel CRC

Maintains a running CRC state register across beats of a single packet.
The output is **combinatorial** — it reflects the accumulated CRC through
the current beat and is valid in the same cycle as the asserted `en`.

```
Parameter     Default            Description
CONFIG        DEFAULT_CRC.cfg    CRC algorithm configuration
DATA_BYTES    1                  Width of the data bus, in bytes
```

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` | in | Clock |
| `srst` | in | Synchronous reset — resets state to `CONFIG.INIT` |
| `en` | in | Enable — process current beat and advance state |
| `mty[$clog2(DATA_BYTES)-1:0]` | in | Empty bytes at the end of this beat; 0 = all bytes valid |
| `data[0:DATA_BYTES-1][7:0]` | in | Input data (byte 0 = first byte of message) |
| `crc[WIDTH-1:0]` | out | Combinatorial accumulated CRC (valid each `en` cycle) |
| `check` | out | Combinatorial; asserts when accumulated register equals `CONFIG.RESIDUE` — i.e. a complete message with its appended FCS was received without error.  Sample on the EOP beat. |

**Typical use:**

```
- Drive en  from (valid && ready).
- Set mty=0 on full beats; set mty to the empty-byte count on the EOP beat.
- Sample crc on the EOP beat to read the full-packet CRC.
- Assert srst one cycle after the EOP beat to reset state for the next packet.
```

`mty` valid range is `[0, DATA_BYTES-1]`.  A beat with zero valid bytes is
not a real transfer; do not assert `en` for one.

**Implementation note:** the state-advance function is a GF(2) matrix-vector
multiply over basis vectors precomputed at elaboration time.  Partial-beat
variants (one basis-vector set per possible valid-byte count) are MUX-selected
at runtime.  Synthesis constant-folds all basis vectors to pure XOR trees.

---

## Verification

`crc_verif_pkg` provides a SystemVerilog reference model that implements the
same REFIN, REFOUT, and XOROUT logic as the RTL.  Testbenches use it to
generate expected values for comparison.

Unit tests live under `tests/` and can be run individually or as a regression:

```sh
# Single test
make -C tests/crc_accum/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform (`*.wdb`), or `SEED=N` to fix the
random seed.
