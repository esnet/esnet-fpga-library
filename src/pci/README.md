# PCI support

PCI-related definitions, interfaces, and verification helpers.

| Library | Description |
|---------|-------------|
| [`pci.vpd`](vpd/README.md) | Vital Product Data resource definitions, byte-access interface, agents, and parsing helpers |

See the sub-library guide for component details and verification capabilities.
Run all PCI suites from this directory:

```sh
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
