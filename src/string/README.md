# String

String formatting and byte-array conversion helpers provided by
`string_pkg`. The string library has no component dependencies. Its
functions are intended for verification messages, diagnostics, and data
dumps.

## Contents

| Function | Description |
|----------|-------------|
| `indent(str, indent_spaces=8, newline=1)` | Prefixes a string with spaces and optionally appends a newline |
| `horiz_line(length=70, newline=1)` | Produces a line of hyphens with an optional trailing newline |
| `byte_array_to_hex_string(ba)` | Concatenates hexadecimal byte representations in array order |
| `byte_array_to_ascii_string(ba)` | Converts ASCII bytes to characters, replacing control bytes below `0x20` with spaces |
| `byte_array_to_string(ba)` | Produces an offset-labelled hexadecimal/ASCII dump |

All functions return a SystemVerilog `string`. They can be called through
`string_pkg` or imported into a testbench/package. Byte-array functions
accept an unpacked array of `byte` values; the first array element appears
first in the output.

## Formatting

`indent()` adds spaces before the supplied string. It does not indent each
line of a multiline string independently. `horiz_line()` repeats `-` for the
requested length. Both append a newline by default; pass `newline=0` when
combining their results into a larger message. Use nonnegative indentation
and line lengths.

```systemverilog
string heading = string_pkg::horiz_line(40);
string detail = string_pkg::indent("Memory initialized", 4);
```

## Byte-array conversions

The hexadecimal formatter emits two hexadecimal digits per byte, without
separators or an address prefix. The ASCII formatter is intended for ASCII
data rather than Unicode decoding; it does not validate the full printable
character range.

`byte_array_to_string()` formats rows of up to 16 bytes. Each row contains a
hexadecimal byte offset, grouped hexadecimal data, and an ASCII view. A
partial final row is padded to preserve column alignment, and each row ends
with a newline. Empty byte arrays produce empty strings.

```systemverilog
byte payload[] = '{8'h41, 8'h42, 8'h43};
string hex_text = string_pkg::byte_array_to_hex_string(payload); // "414243"
string ascii_text = string_pkg::byte_array_to_ascii_string(payload); // "ABC"
```

## Verification

The SVUnit suite checks hexadecimal and ASCII conversion against reference
strings using representative ASCII input. Indentation, horizontal lines,
formatted dumps, and byte-boundary cases are outside the current suite's
coverage.

```sh
# Single testbench
make -C tests/string/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
