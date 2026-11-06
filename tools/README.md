# Bundled tools

Git submodules provide register generation and the SystemVerilog unit-test
framework. Initialize them from the repository root:

```sh
git submodule update --init --recursive
```

## Contents

| Tool | Purpose |
|------|---------|
| [Regio](regio/README.md) | ESnet-maintained register-map elaboration and generation tool, with Python register-access support |
| [SVUnit](svunit/README.md) | SystemVerilog unit-test framework used by the library suites |

Regio translates YAML specifications using the
[library templates](../src/reg/regio-templates/README.md). Its own README
describes Python setup and development commands. Generated register RTL,
packages, and verification agents are emitted into the build output tree.

The shared [SVUnit rules](../scripts/Makefiles/svunit.mk) generate test
runners and prepare them for the supported simulators. Use the library
Makefiles to run tests with xsim or Verilator; the
[repository guide](../README.md#simulation-setup) describes setup and wave
capture. Direct upstream SVUnit invocation does not include the library's
build integration.
