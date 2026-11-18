# Forward error correction

Reed–Solomon encoding and erasure reconstruction over GF(16), with parallel
codeword datapaths and buffered streaming components for larger FEC blocks.
The library also provides data transposition, event framing, padding, and
controlled erasure injection for integration and verification.

## Contents

| Component | Description |
|-----------|-------------|
| `fec_pkg` | Field arithmetic, polynomial helpers, lookup matrices, modes, and metadata |
| `rs_encode`, `rs_decode` | Codeword parity generation and known-erasure reconstruction |
| `rs_decode_h_select` | Pipeline selecting a reconstruction matrix and erasure mask |
| `fec_encode`, `fec_decode` | Parallel codeword and symbol-thread wrappers |
| `fec_err_inject` | Remove selected codeword symbols and compact the surviving data |
| `rs_acc` | Buffered matrix multiply/accumulate over streamed symbol columns |
| `rs_acc_encode`, `rs_acc_decode` | Streaming parity generation and reconstruction |
| `rs_acc_framer` | Derive block and padding metadata from an event's byte length |
| `rs_acc_pad` | Insert or remove padding for partial FEC blocks |
| `rs_acc_err_inj` | Drop selected columns from a streaming codeword block |
| `fec_blk_transpose` | Convert between codeword-major and symbol-column-major layout |
| `fec_col_transpose` | Convert between bit-sliced and symbol-column layout |
| `fec_col_buf`, `fec_bank_buf` | Banked storage supporting buffered column processing |
| `fec_verif_pkg::rs_model` | Polynomial-division reference model for encoder parity |
| `tb_pkg` | Reusable bus-agent environments for parity and round-trip checking |

The RTL depends on [mem](../mem/README.md), [fifo](../fifo/README.md), and
`fec.pkg`. Verification uses the shared standard and bus agents.

## Code configuration and arithmetic

The checked-in [`fec_luts.svh`](pkg/include/fec_luts.svh) specifies GF(16)
with four-bit symbols and a systematic RS(10, 8) code: eight data symbols
and two parity symbols. The generator, parity, reconstruction, and erasure
lookup tables describe this configuration together. They are package
constants, rather than module parameters for arbitrary Reed–Solomon codes.
[`genMatrix_simplified.py`](pkg/include/genMatrix_simplified.py) contains
the supporting table-generation calculations using Python `galois` and
NumPy.

`gf_mul()`, `gf_div()`, and `gf_add()` implement field arithmetic. Addition
is XOR; multiplication and division use lookup tables. Division returns
zero when either operand is zero, including a zero divisor. Polynomial
helpers support the encoder reference model.

Decoding requires known erasure locations. `err_loc` selects a supported
entry in `RS_H_LUT` and `RS_ERR_LOC_LUT`; these tables describe pairs of
erased symbols. The decoder reconstructs data from the surviving symbols
using that matrix. It does not detect unknown error locations or implement
a general error-locating Reed–Solomon decoder.

## Codeword datapaths

`rs_encode` accepts packed data symbols and returns the original data with
separate parity symbols. `rs_decode` accepts compacted surviving symbols,
a reconstruction matrix, and an erasure mask, and returns the recovered
data symbols. `rs_decode_h_select` registers the matrix and mask selected
by `err_loc` alongside the incoming data.

`fec_encode` and `fec_decode` arrange parallel instances of those datapaths
using `DATA_WID` and `NUM_THREADS`. Each symbol position holds interleaved
symbol threads. Select a width containing an integral number of complete
data codewords across those threads. `fec_err_inject` combines data and
parity, removes symbols selected by the erasure mask, and compacts the
survivors for decoding.

These blocks use explicit valid/ready ports and stall their processing
pipelines with downstream readiness. The primitive encoder and decoder
expose `srst` but do not use it to clear their valid pipelines; allow
invalid inputs to propagate before consuming traffic after initialization.

## Streaming interface and metadata

`rs_acc_intf` carries `data`, `valid`, `ready`, and a `fec_meta_t` value on
`clk`. Its `tx` modport drives data, valid, and metadata and receives ready;
`rx` has the opposite directions. Transfers occur when valid and ready
are asserted together on a rising `clk` edge. Hold valid, data, and metadata
stable while stalled; each accepted beat carries its own metadata. The
interface has no reset signal; reset is supplied to connected processing
blocks separately. `DATA_WID` defaults to one bit; set it consistently with
the chosen processing blocks and their geometry.

Metadata accompanies the data stream and describes the FEC block, frame,
and partial-event layout:

| Fields | Purpose |
|--------|---------|
| `parity`, `ec_frame_num` | Distinguish data/parity frames and identify a frame |
| `fec_blk_num`, `fec_blk_size` | Block identity and unpadded block size in bytes |
| `pad_frames`, `pad_bytes` | Padding information for the final block/frame |
| `ec_sgmt_size` | Segment size in bytes |
| `eos`, `keep` | End-of-segment indication and valid-byte information |

Different stages populate the metadata they require. For example,
`rs_acc_framer` derives event and block sizing, while downstream encoding
and transposition stages assign frame and segment information. Supply a
stable `fec_evt_size` before streaming the associated event.

## Buffered processing

`rs_acc` accumulates coefficient-weighted input columns into banked memory.
`rs_acc_encode` inserts padding, forwards data, and emits parity columns;
`rs_acc_decode` selects the reconstruction matrix and recovers data columns.
Its `DELETE_PAD_BYTES` parameter optionally removes padding after decoding.
`rs_acc_err_inj` drops entire columns selected by an erasure mask.

`fec_blk_transpose` selects codeword-to-symbol or symbol-to-codeword layout
with `MODE`. `fec_col_transpose` selects bit-to-symbol or symbol-to-bit
layout. Both use alternating buffers to overlap input storage and output
processing. The column buffers have a fixed memory organization supporting
the supplied streaming datapaths; the presence of width parameters does
not imply that every width or block geometry is supported.

`COL_LEN` is fixed at 4096, and `FEC_BLK_SIZE` defines the unencoded payload
block size as `RS_K * SYM_SIZE * COL_LEN / 8`, currently 16 KiB. Streaming
blocks default to a 512-bit datapath. Choose widths compatible with the
column geometry and pipeline requirements, and keep the selected erasure
pattern consistent for the block being reconstructed.

## Verification

The SVUnit suites compare field arithmetic with lookup tables and encoder
parity with the polynomial reference model. Decoder tests inject known
erasures and compare reconstructed data with the original transactions.
Integration suites exercise parallel coding, transpose round trips, and
streaming encode/inject/decode paths, including partial-event padding.
Shared bus drivers, monitors, and scoreboards provide stimulus and checking.

The suites cover representative datapaths and integration paths; they do
not establish support for every width, erasure sequence, or metadata field.

Run from this directory:

```sh
# Individual testbench
make -C tests/rs/rs_encode/

# Suite groups
make -C tests/rs/regression/
make -C tests/fec/regression/
make -C tests/rs_acc/regression/

# All FEC suites
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
