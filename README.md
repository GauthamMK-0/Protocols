# Hardware Protocols & Interconnect Architecture Reference

A modular, synthesizable SystemVerilog RTL implementation and architectural reference for industry-standard communication protocols, bus standards, and interconnects across embedded systems, Systems-on-Chip (SoC), AI accelerators, and high-performance distributed computing clusters.

---

## 🏛️ Architectural Taxonomy

```
                                  ┌─────────────────────────────────────────────────────────┐
                                  │           Hardware Interconnect Hierarchy               │
                                  └────────────────────────────┬────────────────────────────┘
                                                               │
         ┌──────────────────────────────┬──────────────────────┴───────┬──────────────────────────────┐
         ▼                              ▼                              ▼                              ▼
┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
│  Peripheral &    │          │  On-Chip SoC &   │          │  Host & Coherent │          │  Scale-Out &     │
│  Control Plane   │          │  Streaming Bus   │          │  Interconnect    │          │  Collectives     │
├──────────────────┤          ├──────────────────┤          ├──────────────────┤          ├──────────────────┤
│ • UART           │          │ • APB4           │          │ • PCIe (TLP)     │          │ • RoCEv2 (RDMA)  │
│ • SPI            │          │ • AXI4-Stream    │          │ • CXL (.io/.mem) │          │ • NCCL Engines   │
│                  │          │ • AXI4-Full      │          │ • NVLink         │          │                  │
└──────────────────┘          └──────────────────┘          └──────────────────┘          └──────────────────┘
```

---

## 📂 Repository Structure & Navigation

Each protocol directory is organized as a self-contained module containing synthesizable RTL, an architecture specification document (`readme.md`), and self-checking SystemVerilog testbenches.

```
Protocols/
├── APB4/                 # AMBA 4 Advanced Peripheral Bus (Control & CSRs)
│   ├── apb_master.sv     # APB4 FSM Master with byte-strobe generation
│   ├── apb_slave.sv      # APB4 Slave with memory-mapped registers & PSLVERR
│   ├── tb_apb_top.sv     # Self-checking APB4 verification testbench
│   └── readme.md         # Microarchitecture and timing diagrams
│
├── UART/                 # Universal Asynchronous Receiver-Transmitter
│   ├── baud_rate_gen.sv  # Configurable 16x baud rate clock divider
│   ├── fifo.sv           # Circular buffer FIFO for TX/RX buffering
│   ├── uart_tx.sv        # 8-N-1 Serial Transmitter FSM
│   ├── uart_rx.sv        # 16x Oversampling Receiver with center-sample logic
│   ├── uart_top.sv       # Top-level UART transceiver with FIFO integration
│   ├── tb_uart_top.sv    # Self-checking loopback testbench
│   └── readme.md         # UART architectural specifications
│
├── SPI/                  # Serial Peripheral Interface
│   ├── spi_master.sv     # Configurable SPI Master (Modes 0, 1, 2, 3)
│   ├── spi_slave.sv      # SPI Slave with shift register and chip-select gating
│   └── readme.md         # Timing and mode matrices
│
├── AXI4_Stream/          # AMBA AXI4-Stream Protocol (Data Pipeline)
│   ├── axis_fifo.sv      # Synchronous AXI4-Stream packet FIFO with backpressure
│   └── readme.md         # Handshake mechanics (TVALID/TREADY)
│
├── AXI4_Full/            # AMBA AXI4 Memory-Mapped 5-Channel Bus
│   ├── axi_master.sv     # AXI4 Burst Master (INCR/FIXED/WRAP support)
│   ├── axi_slave.sv      # AXI4 Memory-Mapped Slave with 5 split channels
│   └── readme.md         # Channel synchronization and out-of-order execution
│
├── PCIe_TLP/             # PCI Express Transaction Layer
│   ├── tlp_tx_engine.sv  # TLP Framer (Memory Read/Write, Completions)
│   ├── tlp_rx_engine.sv  # TLP Decoder and Header Extractor
│   └── readme.md         # Header formats, routing, and credit flow control
│
├── CXL/                  # Compute Express Link (CXL.io, CXL.cache, CXL.mem)
│   ├── cxl_flit_parser.sv# 68B/256B Flit Protocol Decoder
│   └── readme.md         # Coherency semantics and memory pooling
│
├── NVLink/               # High-Speed GPU-to-GPU Interconnect
│   ├── nvlink_packet.sv  # Credit-based low-latency packet processor
│   └── readme.md         # Sub-link architecture and flow control
│
├── RoCEv2/               # RDMA over Converged Ethernet v2
│   ├── roce_packet_gen.sv# UDP/IP + InfiniBand BTH/RETH/AETH generator
│   └── readme.md         # Lossless Ethernet, PFC, and zero-copy semantics
│
└── NCCL/                 # Collective Communication Hardware Engines
    ├── ring_allreduce.sv # Hardware Ring AllReduce pipelined datapath
    └── readme.md         # Collective algorithm microarchitectures
```

---

## 🛠️ Verification & Simulation

All modules are written in standards-compliant SystemVerilog and verified using **Verilator** and standard event-driven simulators (Cadence Xcelium, Synopsys VCS, Siemens Questa).

### Prerequisites
- [Verilator](https://www.verilator.org/) (version $\ge$ 5.008 recommended)
- C++ Compiler (`g++` or `clang` with C++17 support)
- GNU Make

### Running Individual Testbenches

#### APB4 Testbench
```bash
verilator --binary --timing APB4/tb_apb_top.sv APB4/apb_master.sv APB4/apb_slave.sv \
          --top-module tb_apb_top -o sim_apb_top && ./obj_dir/sim_apb_top
```

#### UART Top-Level Loopback Testbench
```bash
verilator --binary --timing UART/tb_uart_top.sv UART/uart_top.sv UART/baud_rate_gen.sv \
          UART/fifo.sv UART/uart_tx.sv UART/uart_rx.sv \
          --top-module tb_uart_top -o sim_uart_top && ./obj_dir/sim_uart_top
```

---

## 📊 Summary of Protocol Specifications

| Protocol | Category | Clocking | Flow Control / Handshake | Typical Bitwidth |
| :--- | :--- | :--- | :--- | :--- |
| **UART** | Serial Asynchronous | Async (16x Baud) | Stop bits, Software/Hardware Flow Control | 1-bit serial |
| **SPI** | Synchronous Serial | Sync (`SCK`) | `CS_N` Active-Low Framing | 1-bit serial |
| **APB4** | Control / CSR | Single Clock | `PSEL`, `PENABLE`, `PREADY` | 32-bit / 64-bit |
| **AXI4-Stream** | Dataflow / Pipelined | Single Clock | `TVALID` / `TREADY` | 32 to 1024-bit |
| **AXI4-Full** | High-Throughput Memory | Single Clock | 5 Independent `VALID` / `READY` Channels | 32 to 1024-bit |
| **PCIe (TLP)** | Packetized IO | High-Speed Serial | Credit-Based (Posted, Non-Posted, CPL) | $\times1$ to $\times16$ Gen1-Gen6 |
| **CXL** | Coherent Memory / IO | High-Speed Serial | Flit-based Credit Flow Control | Gen5/Gen6 PHY |
| **NVLink** | GPU Interconnect | High-Speed Serial | Credit-Based Flit Protocol | Sub-link Lanes |
| **RoCEv2** | Scale-Out Network | Network Clock | PFC (802.1Qbb), ECN, Credit Flow | 100G / 400G / 800G |
| **NCCL** | Collective Accelerators | Fabric Clock | Ring / Tree Token Handshake | Multi-GPU Ring |

---

## 📄 License
This project is open-source and released under the [MIT License](LICENSE).
