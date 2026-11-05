# PCAP

SystemVerilog helpers for reading, parsing, and displaying packet captures
in classic PCAP format. The library is intended for verification and depends
on `string.pkg` for packet-data formatting.

## Contents

| Component | Description |
|-----------|-------------|
| `pcap_pkg` | Capture types, file loading, header decoding, byte-order conversion, and diagnostic output |
| `pcap_hdr_t` | Packed global header, including format, snapshot length, and link-layer type |
| `pcap_record_hdr_t` | Packed packet header, including timestamp and captured/original lengths |
| `pcap_record_t` | Packet header and a queue of captured payload bytes |
| `pcap_t` | Global header and a queue of packet records |
| `pcap_meta_t` | Header validity, timestamp resolution, and byte-order information |

## Reading captures

`read_pcap(filename)` loads a file and returns a `pcap_t`. `parse(data)`
accepts a queue of bytes containing the same file representation. Returned
headers have normalized byte order; payload bytes remain in capture order.
The parser accepts both byte orders and microsecond- or nanosecond-resolution
magic numbers. The record field `ts_usec` holds the fractional timestamp in
the resolution identified by the global header.

```systemverilog
pcap_pkg::pcap_t capture;
capture = pcap_pkg::read_pcap("traffic.pcap");
pcap_pkg::print_pcap(capture);

foreach (capture.records[i]) begin
    // Captured bytes are in capture.records[i].pkt_data.
end
```

`read_to_bytes(filename, data)` provides raw file access. `pop_hdr(data)` and
`pop_record_hdr(data)` consume a header from the front of a byte queue,
leaving subsequent bytes in place. These extraction helpers preserve the
encoded byte order; `parse_hdr(hdr)` identifies the magic number, resolution,
and whether conversion is needed. `swap_hdr_endianness()` and
`swap_record_hdr_endianness()` perform in-place header conversion.

Zero-length packet records are preserved. Captured length (`incl_len`)
determines the payload size; original length (`orig_len`) is retained as
metadata. Reading loads the entire capture into memory. Missing files,
unrecognized magic numbers, and incomplete headers or payloads are reported
as simulation errors. This is a classic PCAP reader; PCAPNG and capture
writing are outside its scope.

## Diagnostic output

`print_pcap()` displays the global header, packet headers, and hexadecimal/
ASCII payload dumps. Individual helpers are available as `print_hdr()`,
`print_record_hdr()`, `print_pkt_data()`, and `print_raw()`. Pass
`ns_resolution=1` to `print_record_hdr()` for nanosecond timestamp labels;
`print_pcap()` selects labels from the capture header automatically.

## Verification

The SVUnit suite exercises capture-file parsing with microsecond and
nanosecond timestamps, zero-length packet records, and diagnostic output.
Header-extraction checks verify field byte order and preservation of the
remaining byte queue. Malformed-input rejection is outside the current
suite's coverage.

```sh
# Single testbench
make -C tests/pcap/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
