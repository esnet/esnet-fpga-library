# PCI Vital Product Data

Definitions and verification infrastructure for PCI Vital Product Data
(VPD). The library provides resource-header helpers, byte-access and
initialization interfaces, a resource-reading agent, and VPD-R record parsing and display
functions. It does not implement a PCI configuration-space controller or
VPD storage device.

## Contents

| Component | Description |
|-----------|-------------|
| `pci_vpd_pkg` | Small/large resource headers, supported tags, and header helpers |
| `pci_vpd_intf` | Clocked byte request and read-response interface |
| `pci_vpd_card_info_intf` | Read-only card-info cache request/response interface |
| `pci_vpd_ctrl_intf` | Free-running VPD clock/reset and initialization control/status |
| `pci_vpd_agent` | Abstract byte transport with resource reading and cached VPD data |
| `pci_vpd_intf_agent` | Clocking-block transport for `pci_vpd_intf` |
| `pci_vpd_verif_pkg` | Resource/record types, lookup, VPD-R parsing, and formatting helpers |

`pci.vpd.pkg` has no component dependencies. `pci.vpd.rtl` uses that
package, and `pci.vpd.verif` also uses the shared standard verification
infrastructure and [string helpers](../../string/README.md).

## Resource headers

`VPD_ADDR_WID` is 15, describing a byte-addressed VPD space of up to 32 KiB.
`vpd_rdt_t` is a packed union exposing a raw header byte and its small or
large resource interpretation.

Small headers contain the resource type, tag, and payload length. Large
headers contain the resource type and tag; their payload length follows
in little-endian order. Supported tags include `ID`, `VPD-R`, `VPD-W`, and
`END`. Unknown tag values are returned as `VPD_TAG_INVALID`.

| Helper | Purpose |
|--------|---------|
| `vpd_get_srdt()`, `vpd_get_lrdt()` | Construct small and large header bytes |
| `vpd_get_type()`, `vpd_get_tag()` | Decode a header and validate its tag |
| `vpd_get_small_tag()` | Convert a tag to the small-header representation |
| `vpd_get_tag_name()` | Return a display name for a supported tag |

## Byte-access interface

`pci_vpd_intf` carries byte transactions on `clk`:

| Signal | Direction from controller | Purpose |
|--------|---------------------------|---------|
| `req` | Output | Request strobe |
| `wr_rd_n` | Output | Write (`1`) or read (`0`) |
| `addr` | Output | Byte address |
| `wr_data` | Output | Byte to write |
| `rd_data` | Input | Returned read byte |
| `rd_vld` | Input | Read-response indication |

The `controller` and `peripheral` modports define these directions. The
verification clocking block samples and drives on rising edges of `clk`
with the default clocking skews. Transaction sequencing belongs to the
agent; the interface contains signals, modports, and the clocking block.

Issue one transaction at a time. There is no ready signal, write
acknowledgement, error response, or response identifier. The peripheral
must accept each requested write and return a read byte with `rd_vld`.
Reset behavior belongs to the connected peripheral.

## Card information and initialization

`pci_vpd_card_info_intf` describes a read-only byte cache. The `provider`
drives `vld`, `error`, the nine-bit `len`, and byte responses (`rd_data`,
`rd_vld`). The `consumer` drives byte requests (`rd`, nine-bit `rd_addr`).
The provider keeps the cache and length stable while valid. Issue one read
at a time and sample returned data only when `rd_vld` is asserted. The
interface does not define the cache's record encoding.

`pci_vpd_ctrl_intf` groups the free-running `clk`, active-high synchronous
`srst`, diagnostic `init_done_mask`, and initialization status. Its
`controller` supplies clock/reset/mask; the `peripheral` supplies `init_done`,
`init_error`, `init_timeout`, `init_early_read`, and 14-bit `init_time_ms`.
Card-info transfers and initialization control/status share this clock
domain. Reset is independent of PCIe configuration-interface reset.

These interfaces carry signals only. Clock frequency, function count and
provider enablement remain configuration parameters of connected modules.
Verification clocking blocks are excluded from synthesis.

## Agents and resource reading

`pci_vpd_agent` defines the abstract byte read/write and idle hooks.
`read_byte()` and `write_byte()` provide byte access; use addresses within
the VPD space. `read()` walks resources from byte zero until an end tag,
invalid tag, or the end of the address space. It preserves resource tags,
payloads, and byte sums, rejecting resource lengths that exceed the
remaining address space.

`get_vpd()` returns the cached database, `is_valid()` reports whether an end
tag was reached, and `to_string()` formats the cached data. Database
validity is separate from VPD-R record validity and checksum validation.
The byte convenience methods do not return transport error/timeout flags;
those are available to derived agents through the protected transport
hooks.

To use `pci_vpd_intf_agent`, assign its public `vpd_vif` handle to the
interface and call the inherited lifecycle methods as needed. The agent
aligns requests to clocking events and holds each request for a full
cycle. Writes complete after the request cycle, without acknowledgement.
Reads wait for a sampled `rd_vld` and use `set_rd_timeout()` to limit the
wait, defaulting to 50 interface clock cycles; zero disables the limit.
The base agent retains a write timeout setting for derived transports,
while direct-interface writes have no completion wait to time out.
Callers must serialize accesses to the agent.

## VPD-R parsing and display

`vpd_t` stores resource entries, each with a tag, byte-array value, and
byte sum. `vpd_get_resource()` finds a resource by tag and returns an
invalid resource with an empty value when absent.

`vpd_parse_vpd_r()` extracts named records from a VPD-R resource into a
`vpd_r_t`. Each record has a two-byte name, a byte length, and a byte-array
value. The parser rejects truncated records and reports record validity
and checksum validity separately. `vpd_r_get_record_value()` finds a named
record and returns an empty array when absent.

For a final `RV` record, the checksum includes bytes through its first
value byte. Remaining reserved bytes are excluded, matching the
[pciutils VPD reader](https://github.com/pciutils/pciutils/blob/master/ls-vpd.c).
Resource sums supplied to the parser must include headers and complete
payloads, as produced by `pci_vpd_agent.read()`.

The `vpd_to_string()`, `vpd_resource_to_string()`, `vpd_r_to_string()`, and
`vpd_record_to_string()` helpers format resources and records for reports.
VPD-W payloads can be read as resources; structured VPD-W record parsing
is not provided.

## Verification

The SVUnit suites check header encoding, known and unknown tags, record
lookup, VPD-R checksums, reserved checksum bytes, truncated records, and
large-resource formatting. A byte-addressable peripheral model exercises
the interface agent, delayed read responses, bounded and unbounded waits,
timeout recovery, resource-length decoding, and complete resource reading
followed by VPD-R parsing.

These tests exercise the library's interface and parsing helpers, without
modeling PCI configuration-space accesses or a physical VPD storage device.
Stimulus and monitoring use clocking blocks.

Run from this directory:

```sh
# Individual testbench
make -C tests/pci_vpd_agent/

# All VPD suites
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
