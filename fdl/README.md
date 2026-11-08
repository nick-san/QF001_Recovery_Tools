# Unisoc UMS512 (UIS7862 / T610 / T618) FDL Bootloaders

These FDL (Flash Download Loader) binaries are used by SPD tools (`spd_dump`) to communicate with the SoC during BootROM (BROM) download mode.

* **Source Repository**: [TheGammaSqueeze/UnisocBypass](https://github.com/TheGammaSqueeze/UnisocBypass) (MIT License)
* **Target SoC**: Unisoc UMS512 (SharkL5Pro / UIS7862 / UIS7862S)

---

## Files

1. **`fdl1-dl.bin`**:
   - **Target Address**: `0x5500` (SRAM)
   - **Role**: Stage 1 boot loader. Initializes LPDDR4 DRAM memory controller and prepares system memory to receive FDL2.
2. **`fdl2-dl.bin`**:
   - **Target Address**: `0x9efffe00` (DRAM)
   - **Role**: Stage 2 boot loader (based on U-Boot 2015.07). Implements download mode protocol and executes eMMC read/write operations.

---

## Notice & Disclaimer

These binaries are included for device rescue, interoperability, and recovery purposes. Intellectual property rights belong to their respective original copyright holders (Unisoc / Spreadtrum Communications).
