# Math

Integer and bit-vector utilities provided by `math_pkg`. The `math.pkg`
component has no library dependencies. Integer helpers are intended for
parameter calculations; the vector helper can also be used in logic.

## Contents

| Function | Description |
|----------|-------------|
| `MIN(a, b)` | Smaller of two signed integers |
| `MAX(a, b)` | Larger of two signed integers |
| `ABS(a)` | Absolute value of a signed integer |
| `GCD(a, b)` | Greatest common divisor, using the Euclidean algorithm |
| `LCM(a, b)` | Least common multiple, retaining the sign of the input product |
| `vec#(WID)::count_ones(value)` | Counts set bits in a vector of width `WID` |

## Integer helpers

The integer functions take and return SystemVerilog `int` values. They can
be called through `math_pkg` or imported into a module/package, including
in constant expressions:

```systemverilog
localparam int INPUT_BYTES = 6;
localparam int OUTPUT_BYTES = 8;
localparam int BLOCK_BYTES = math_pkg::LCM(INPUT_BYTES, OUTPUT_BYTES);
localparam int COUNT_WID = math_pkg::MAX(1, $clog2(BLOCK_BYTES + 1));
```

`GCD` accepts negative operands and returns a nonnegative divisor when the
result is representable. `GCD(a, 0)` is `ABS(a)` and `GCD(0, 0)` is zero.
`LCM` computes `a * b / GCD(a, b)`: one negative operand produces a negative
result, while two negative operands produce a positive result. With one
zero operand and a nonzero other operand, it returns zero; do not pass zero
for both operands because that divides by zero.

Arithmetic uses signed 32-bit integers. Keep intermediate products and
magnitudes within that range. In particular, `ABS` cannot represent the
positive magnitude of the most negative `int`, and `LCM` multiplies before
dividing, so its intermediate product can overflow even when the final
mathematical result would fit.

## Vector population count

`vec` is a parameterized helper class with a static `count_ones()` function;
no object allocation is needed. `WID` defaults to `1` and must be positive.
The input is `logic[WID-1:0]`, and the result has `$clog2(WID+1)` bits so it
can represent a count from zero through `WID`.

```systemverilog
typedef math_pkg::vec#(32) word_math_t;
logic [31:0] data;
logic [5:0] ones;

assign ones = word_math_t::count_ones(data);
```

## Verification

The SVUnit suite checks the integer helpers in constant expressions and
runtime calls, including randomized operands, signed combinations, and
zero cases. The vector population-count helper and integer overflow cases
are outside the current suite's coverage.

```sh
# Single testbench
make -C tests/math/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
