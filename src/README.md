# Source libraries

Reusable RTL and verification components organized by function. Each guide
lists the provided modules, describes important interface contracts, and
summarizes test capability and limitations. Test setup, simulator selection,
seeds, and wave capture are described in the
[repository guide](../README.md#simulation-setup).

## Interfaces and data movement

| Library | Purpose |
|---------|---------|
| [APB](apb/README.md) | Peripheral bus interfaces and register adapters |
| [AXI3](axi3/README.md) | Burst interfaces, channel pipelines, and memory adapter |
| [AXI4](axi4/README.md) | Burst interfaces and simulation agents/models |
| [AXI4-Lite](axi4l/README.md) | Register interconnect, adapters, and clock crossing |
| [AXI4-Stream](axi4s/README.md) | Streaming interfaces and packet adapters |
| [Bus](bus/README.md) | Generic ready/valid payload paths |
| [Packet](packet/README.md) | Packet streams, descriptors, storage, and queues |
| [Registers](reg/README.md) | Register primitives, agents, and generated maps |
| [Regio templates](reg/regio-templates/README.md) | Register RTL and verification generation conventions |
| [Register endian](reg/endian/README.md) | Register byte-order checks |
| [Register proxy](reg/proxy/README.md) | Indirect register access |
| [Register examples](reg/example/README.md) | Register blocks, decoding, and clock crossing |

## Storage and lookup

| Library | Purpose |
|---------|---------|
| [Allocation](alloc/README.md) | Bitmap, linked-list, and scatter/gather allocation |
| [Database](db/README.md) | Key/value storage and management interfaces |
| [FIFO](fifo/README.md) | Synchronous/asynchronous buffering and monitoring |
| [FIFO AXI4-Lite](fifo/axil/README.md) | Register-accessible FIFO status and control |
| [Hash tables](htable/README.md) | Hash lookup, cuckoo insertion, and update buffering |
| [Memory](mem/README.md) | Memory interfaces, RAM wrappers, and initialization |
| [Memory infrastructure](mem/infra/README.md) | Buffered muxing and aggregation |
| [Memory proxy](mem/proxy/README.md) | Register-controlled memory access |
| [SAR](sar/README.md) | Segmentation and reassembly |
| [State](state/README.md) | Indexed state updates, monitoring, and caches |

## Processing and support

| Library | Purpose |
|---------|---------|
| [Arbitration](arb/README.md) | Priority and round-robin arbitration |
| [CRC](crc/README.md) | Parallel CRC calculation, accumulation, and trimming |
| [FEC](fec/README.md) | Galois-field arithmetic and Reed–Solomon processing |
| [Math](math/README.md) | Integer and bit-vector helpers |
| [PCAP](pcap/README.md) | Capture-file parsing and diagnostics |
| [PCI](pci/README.md) | PCI support overview |
| [PCI VPD](pci/vpd/README.md) | Vital Product Data packages and formatting |
| [Standard](std/README.md) | Common checks, reset/events, and block CDC wrappers |
| [Standard verification](std/verif/README.md) | Transactions, agents, models, environments, and scoreboards |
| [String](string/README.md) | Simulation string and byte-array conversion |
| [Synchronization](sync/README.md) | Clock-domain crossing and reset synchronizers |
| [Timer](timer/README.md) | Tick generation, counters, and expiry checking |
| [Utilities](util/README.md) | Data and synchronous reset pipelines |

## Vendor integration

| Library | Purpose |
|---------|---------|
| [Xilinx](xilinx/README.md) | Vendor component overview |
| [Xilinx RAM](xilinx/ram/README.md) | LUTRAM, BRAM, and UltraRAM inference templates |
| [Xilinx VitisNetP4](xilinx/vitisnetp4/README.md) | P4 IP generation and xsim control-plane verification |

There is no single source-root regression target. Use the entry points in
each library guide, including separate nested or level-specific suites.
Some packages are tested through consuming libraries rather than dedicated
testbenches. Vendor IP restrictions are documented with the affected
components.
