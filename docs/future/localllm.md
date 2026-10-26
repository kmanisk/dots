# Local LLM Hardware Performance, Architecture & MoE Offload Roadmap

**Target Machine:** ASUS TUF Gaming F16 (FX608JH-RV057WS)  
**GPU:** NVIDIA GeForce RTX 5050 Mobile (8 GB GDDR7, 384 GB/s bandwidth, Blackwell `sm_120`)  
**CPU:** Intel Core i5-13450HX (10 cores: 6 Raptor Cove P-cores up to 4.6 GHz, 4 Gracemont E-cores up to 3.4 GHz, 16 threads, 20 MB Intel Smart Cache, AVX2 / FMA3)  
**Memory Architecture:** Intel 13th Gen Raptor Lake memory controller (clamped to max DDR5-4800, max theoretical bandwidth 76.8 GB/s dual-channel, 38.4 GB/s single-channel)  
**Installed Memory:** 1x 16 GB DDR5-5600 running at 4800 MT/s (single-channel baseline, Slot 2 unpopulated)  
**Target Upgraded Memory:** 2x 16 GB DDR5-4800 / 5600 (32 GB dual-channel baseline)  
**Inference Runtimes:** `llama.cpp` / Ollama / LM Studio (GGUF quantization, ~4–8K working context)

---

## 1. Physical Hardware Audit & Memory Population

### 1.1 Physical Memory Audit (DMI Table 17)
Verified on the machine via direct hardware inspection:

```bash
sudo dmidecode --type 17 | grep -E 'Memory Device$|Size:|Speed:|Configured Memory Speed:|Manufacturer:|Part Number:'
```

```text
Memory Device
    Size: 16 GiB
    Speed: 5600 MT/s
    Configured Memory Speed: 4800 MT/s
Memory Device
    Size: No Module Installed
```

### 1.2 Architectural Implications
1. **Physical DIMM Speed vs. Memory Controller Clamp**:
   - While the physical module is sold as a DDR5-5600 SO-DIMM, the Intel Core i5-13450HX processor officially caps memory speeds at **DDR5-4800**.
   - Operating speed is correctly clamped to 4800 MT/s.
2. **Current Single-Channel Penalty**:
   - Because only Slot 1 is populated (1x 16 GB), the system operates on a single 32-bit DDR5 subchannel pair.
   - Peak theoretical memory bandwidth is capped at **~38.4 GB/s**.
3. **Empty Expansion Slot**:
   - Slot 2 is completely unpopulated. Adding a second 16 GB module achieves true dual-channel operation, doubling theoretical bandwidth to **76.8 GB/s**.

---

## 2. Indian Market Memory Pricing Analysis & Upgrade Strategy (October 2026)

### 2.1 Current Market Retail Pricing (India)
Retail listings across Indian hardware distributors (PrimeABGB, Vishal Peripherals, Computech Store) show severe price inflation for DDR5 laptop SO-DIMMs:

| DDR5-5600 SO-DIMM Module | Retail Price Range (INR) |
| :--- | :--- |
| **16 GB EVM** | ~₹21,500 |
| **16 GB Crucial** | ~₹24,000 – ₹28,000 |
| **16 GB ADATA** | ~₹27,000 |
| **16 GB Kingston** | ~₹28,000+ |
| **32 GB Single Module** | ~₹40,000 – ₹52,000 |
| **32 GB Kit (2x 16 GB)** | ~₹45,000 – ₹55,000 |

### 2.2 Upgrade Value Verdict
- **Current Assessment**: Terrible value. Paying ₹22,000 to ₹28,000 for a single 16 GB stick solely to run local LLMs is not economically sound.
- **Recommended Strategy**: Retain the current 16 GB single-stick configuration and run optimized 4B–9B models that reside 100% inside the RTX 5050's 8 GB GDDR7 VRAM.

### 2.3 Target Price Threshold to Execute Upgrade
Wait for market prices to normalize to standard baseline levels before purchasing:
- **Target Price for 1x 16 GB DDR5-5600 SO-DIMM**: `₹4,000 – ₹6,000`
- **Target Price for 32 GB Kit (2x 16 GB)**: `₹8,000 – ₹12,000`

When prices hit this threshold, purchase a single matching **16 GB DDR5-5600 SO-DIMM** to achieve a `16 GB + 16 GB = 32 GB` dual-channel configuration.

---

## 3. Deep Architecture: How CPU-MoE Offloading Operates

The claim that *"inactive experts sit in RAM and are streamed into the processor on demand"* is oversimplified. In actual `llama.cpp` and LM Studio CPU-MoE offloading, the execution is partitioned as follows:

```
+-------------------------------------------------------------------------------+
|                 NVIDIA GeForce RTX 5050 Mobile (8 GB GDDR7 @ 384 GB/s)        |
+-------------------------------------------------------------------------------+
|  - Always-active tensors (token embeddings, RMSNorm, shared expert layers)     |
|  - Attention projections (Q, K, V, O projections) & working KV-cache           |
|  - High-priority routed experts (as many full layers as fit in VRAM)           |
|  - VRAM Expert Cache (caches frequently activated experts dynamically)        |
+---------------------------------------+---------------------------------------+
                                        | (Token activations)
                                        v
+-------------------------------------------------------------------------------+
|                    System RAM (DDR5-4800 Single / Dual-Channel)               |
+-------------------------------------------------------------------------------+
|  - Remaining routed MoE expert weights (~14.6 GB in Q4 quantizations)         |
+---------------------------------------+---------------------------------------+
                                        |
                            Processed DIRECTLY by CPU
                                        v
+-------------------------------------------------------------------------------+
|                       Intel Core i5-13450HX CPU Cores                         |
+-------------------------------------------------------------------------------+
|  - 6 Raptor Cove P-cores execute active expert math via AVX2 / FMA3           |
|  - Eliminates PCIe bus transfer bottleneck for every generated token          |
+-------------------------------------------------------------------------------+
```

### Key Architectural Takeaways:
1. **CPU Execution of RAM Experts**: Inactive experts in RAM are **not transferred over the PCIe bus** to the GPU per token. Instead, the CPU computes the active expert matrices directly in system RAM using AVX2 instructions across its 6 P-cores.
2. **Memory Bandwidth Bottleneck**: Because the CPU must read expert weights from system RAM during every decode step, system memory bandwidth becomes the primary performance limiter.
3. **Non-Linear Bandwidth Scaling**: Doubling memory bandwidth (from 38.4 to 76.8 GB/s) does **not** double token generation speed linearly. CPU AVX2 compute bottlenecks, thread contention, quantization dequantization overhead, context length, and `llama.cpp` expert cache hit rates all contribute to the final decode speed.

---

## 4. Comprehensive Performance & Decode Estimates (RTX 5050 Laptop)

Estimates assume `llama.cpp` / GGUF backend, ~4–8K context window, and Q4-class quantization where practical. Generation/decode speeds reflect realistic expectations:

| Parameter Size | Example Model | Architecture | Approx Model Size | Current 16 GB RAM (Single-Channel) | Future 32 GB RAM (Dual-Channel) | Practical Engineering Verdict |
|---:|---|---|---:|---:|---:|---|
| **4B** | Qwen3.5-4B Q4_K_M | Dense | ~4.0 GB | **70–90 tok/s** | **70–90 tok/s** | Extremely fast; 100% VRAM resident |
| **7–8B** | Qwen3-8B Q4_K_M | Dense | ~5.0–6.0 GB | **45–65 tok/s** | **45–65 tok/s** | Excellent; 100% VRAM resident |
| **9B** | Qwen3.5-9B Q4_K_M | Dense | ~7.0 GB | **40–50 tok/s** | **40–50 tok/s** | **Current sweet spot**; fits fully in VRAM |
| **12B** | Gemma-class 12B Q4 | Dense | ~7.5–8.5 GB | **20–30 tok/s** | **22–32 tok/s** | Borderline VRAM fit; tight KV-cache |
| **14B** | Qwen3-14B Q4 | Dense | ~9.0–10.0 GB | **10–15 tok/s** | **13–18 tok/s** | Partial CPU offload; usable |
| **20B** | Typical 20B dense Q4 | Dense | ~12.0–13.0 GB | **6–10 tok/s** | **8–13 tok/s** | Noticeably sluggish for interactive chat |
| **22–24B** | Mistral Small 24B Q4 | Dense | ~14.0–16.0 GB | **4–6 tok/s** | **5–8 tok/s** | Slow; heavy CPU compute penalty |
| **27B** | Qwen3.6-27B Q4_K_M | Dense | ~17.0–18.0 GB | **~3–5 tok/s** | **~4–7 tok/s** | High quality, but painfully slow |
| **30B-A3B** | Qwen3-30B-A3B | **MoE (~3B active)** | ~18.0 GB Q4 | **12–20 tok/s** | **25–35 tok/s** | Very strong with dual-channel RAM |
| **35B-A3B** | Qwen3.6-35B-A3B | **MoE (3B active)** | ~20.0–22.0 GB Q4 | 2/3-bit: **12–18 tok/s** | **20–30+ tok/s (Q4)** | **Best large-model target at 32 GB** |
| **35B dense** | Generic dense 35B | Dense | ~22.0 GB | **2–3 tok/s** | **2–4 tok/s** | Prohibited; unviable interactive speed |

*[NOTE] Published baseline benchmarks on the RTX 5050 put Qwen3.5-4B Q4 at ~81 tok/s, Qwen3.5-9B Q4 at ~45 tok/s, Qwen3-14B Q4 at ~12–13 tok/s, Mistral Small 24B Q4 at ~4 tok/s, and Qwen3.6-27B at ~3.5–4 tok/s when CPU offload occurs.*

---

## 5. The Dense vs. MoE Scaling Paradox

Dense models follow a rigid scaling degradation: as parameter count increases, every single parameter must be evaluated for every decoded token.

```
Dense Model Parameter Scaling:
4B Dense        [####]                                ~80 tok/s
9B Dense        [########]                            ~45 tok/s
14B Dense       [##############]                      ~12 tok/s
24B Dense       [########################]            ~5 tok/s
27B Dense       [###########################]         ~4 tok/s
35B Dense       [###################################] ~3 tok/s
```

Mixture-of-Experts (MoE) completely breaks this linear penalty:

```
Qwen3.6-27B Dense Model
[###########################]  27B parameters evaluated every token
--> Throughput: ~3–5 tok/s (Severe CPU compute/RAM bottleneck)

Qwen3.6-35B-A3B MoE Model
[###]                         3B parameters activated per token (8 routed + 1 shared)
--> Throughput: ~20–30+ tok/s (With dual-channel RAM and VRAM offload)
```

**Technical Reason**: Officially, Qwen3.6-35B-A3B contains **35 billion total parameters**, but only **3 billion parameters are activated per token** (256 routed experts with 8 routed + 1 shared expert). As a result, Qwen3.6-35B-A3B runs substantially faster than Qwen3.6-27B dense on this laptop, despite having a larger total parameter count.

---

## 6. Practical Four-Tier Strategy

Avoid running 20B–27B dense models on this 8 GB GPU. While they offer slightly higher reasoning quality than 9B, generating at 3–5 tokens/second is too slow for interactive coding and interview copiloting.

| Tier | Purpose | Recommended Model | Hardware Requirement | Expected Throughput |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | Instant / Low-latency tasks | **Qwen 3.5 4B Q4** / **LFM 2.5** | Current 16 GB + 8 GB VRAM | **70–90 tok/s** |
| **Tier 2** | Everyday coding & chat sweet spot | **Qwen 3.5 9B Q4_K_M** | Current 16 GB + 8 GB VRAM | **40–50 tok/s** |
| **Tier 3** | Maximum tolerable dense quality | **Qwen 3 14B Q4** | Current or Upgraded | **10–18 tok/s** |
| **Tier 4** | Advanced reasoning & interview target | **Qwen 3.6 35B-A3B Q4** | **32 GB RAM Upgrade Required** | **20–30+ tok/s** |

### The Progression Path:
- **Now (16 GB Single-Channel)**: Run **`Qwen3.5-9B Q4_K_M`** (~45 tok/s). It fits entirely in GDDR7 VRAM, avoiding system RAM contention.
- **Later (32 GB Dual-Channel)**: Upgrade directly to **`Qwen3.6-35B-A3B Q4`** (~20–30+ tok/s). Skip intermediate dense models (20B–27B).

---

## 7. Future 32 GB RAM Upgrade Deep Dive (Adding 1x 16 GB Stick)

Upgrading to **32 GB DDR5** transforms this laptop into a capable local MoE inference station.

### 7.1 Quantization Sizing Hierarchy (Qwen3.6-35B-A3B)

| Quantization Format | Bits per Weight (bpw) | Model File Size | Viability on 32 GB RAM + 8 GB VRAM |
| :--- | :--- | :--- | :--- |
| **Q2** | ~2.00 bpw | ~11.0–12.0 GB | Easy, but causes unnecessary logic and coding degradation |
| **Q3-ish (Imatrix)** | ~2.69 bpw | ~11.7 GB | Fully viable; leaves massive RAM buffer |
| **Q3_K_M** | ~3.39 bpw | ~14.7 GB | Fully viable |
| **Q4_K_M (Official ggml-org)** | ~4.50 bpw | **~20.4 GB** | **Optimal Target Sweet Spot** |
| **Q5_K_M** | ~5.00 bpw | ~23.0–25.0 GB | Functional, but leaves tight context headroom |
| **Q6_K** | ~6.00 bpw | ~27.0 GB | Heavily context-constrained |
| **Q8_0** | ~8.00 bpw | ~37.0 GB | Not practical; exceeds memory limits |

### 7.2 Memory Allocation Map at 32 GB

```
32 GB Total System RAM
│
├── ~4.5 – 6.0 GB   Host OS (Linux/Sway or Windows 11) + Browser + Terminals
├── ~14.6 – 16.0 GB Offloaded MoE expert weights in RAM
├── ~4.0 – 6.0 GB   Context window / KV-cache / Working memory (8K–32K context)
└── ~4.0 – 6.0 GB   Free safety headroom (prevents swap thrashing)

8 GB RTX 5050 GDDR7 VRAM
│
├── ~6.5 GB         GPU-resident tensors (attention, shared experts, VRAM expert cache)
├── ~1.0 GB         GPU KV-cache allocation
└── ~0.5 GB         VRAM safety buffer / DWM overhead
```

### 7.3 Context Window Guidelines
While Qwen3.6-35B supports an advertised 262K native context window, running 262K locally is unviable due to massive KV-cache memory expansion.
- **Recommended Local Context**: **8,192 to 32,768 tokens (8K–32K)**.
- At 8K–32K, context memory consumes ~2–4 GB of memory, preserving interactive decode speeds.

### 7.4 Non-AI System Benefits of the 32 GB Upgrade
Beyond local LLMs, upgrading to 32 GB dual-channel DDR5 provides substantial workstation improvements:
- Eliminates memory exhaustion during heavy C++/Rust compilation passes.
- Provides ample memory for running background Windows VFIO virtual machines or Waydroid containers without host paging.
- Removes single-channel memory bandwidth bottlenecks in CPU-bound competitive games.
