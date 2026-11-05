# Register byte-order checker

`reg.endian` provides an AXI4-Lite register block for checking that software
and hardware agree on register byte ordering. Writable scratchpads feed
read-only monitors that expose the same data in packed and unpacked forms.

## Contents

| Component | Description |
|-----------|-------------|
| `reg_endian_check` | Scratchpad storage and byte-order monitoring logic |
| [`reg_endian_check.yaml`](regio/reg_endian_check.yaml) | Register map used to generate the block, interface, types, and agent |

`reg.endian.rtl` depends on its generated `reg.endian.regio.rtl` component
and the [AXI4-Lite library](../../axi4l/README.md).

## Register behavior

`reg_endian_check` has an `axi4l_intf.peripheral` port named `axil_if`.
The generated register block and monitor updates use its clock and reset.
Scratchpad and monitor registers reset to zero.

| Registers | Behavior |
|-----------|----------|
| `scratchpad_packed` | Writable packed word |
| `scratchpad_packed_monitor_byte_0` through `_byte_3` | Read-only views of successive bytes of the packed scratchpad |
| `scratchpad_unpacked_byte_0` through `_byte_3` | Independently writable byte fields in separate registers |
| `scratchpad_unpacked_monitor` | Read-only word assembled from the unpacked scratchpads |

Byte zero corresponds to bits `[7:0]`, with successive bytes occupying
higher bits. For example, writing `32'h44332211` to `scratchpad_packed`
produces monitor bytes `8'h11`, `8'h22`, `8'h33`, and `8'h44`. Writing those
values to the unpacked scratchpads produces `32'h44332211` in the packed
monitor. Monitor values update through registered hardware readback paths.

The block exposes byte ordering for inspection; it does not perform bus
byte swapping. Use the generated register types and offsets from the YAML
specification when integrating software or verification clients. See the
[Regio templates](../regio-templates/README.md) for generation details.

## Verification

The SVUnit suite uses generated named-register methods over an AXI4-Lite
register agent. It checks randomized packed-to-unpacked and
unpacked-to-packed readback against the expected byte ordering.

Run from this directory:

```sh
# Individual testbench
make -C tests/reg_endian_check/

# Regression
make -C tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
