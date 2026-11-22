# BOREN STORE - AUTO BUILD SOIL FARM PRO

Skrip otomatisasi Auto Soil & Block Farm Builder Pro untuk Growlauncher dengan dukungan pola 3-Zigzag, Wooden Platform sisi, Auto Restock Block, dan Console ImGui.

## Repository Khusus
Repository ini dikhususkan **HANYA** untuk skrip dan loader **Build Soil**.
Tidak ada file dari skrip lain (Plant, Dirt Farm, Soil Builder, Transfer, Harvest) yang tercampur di sini.

## File Utama
- `auto_soil_builder.lua`: Skrip mandiri lengkap (Full Engine & UI)
- `loader.lua`: Loader langsung untuk `auto_soil_builder.lua` dengan auto-fetch & auto-update dari GitHub
- `loader_soil_builder.lua`: Loader Console ImGui khusus fitur Build Soil
- `mod_soil_builder.lua`: Modul ImGui Console
- `imgui_hub/`: Direktori bootloader dan dependensi runtime Console ImGui mandiri

## Cara Menjalankan di Growlauncher
1. **Menggunakan Loader Otomatis:**
   Eksekusi kode berikut di executor Growlauncher:
   ```lua
   fetch("https://raw.githubusercontent.com/rendhi69/sc_build_soil_farm_growlauncher-/main/loader.lua?v=" .. os.time())()
   ```
   atau jalankan file `loader.lua` yang tersimpan di perangkat Anda.

2. **Menggunakan Console ImGui:**
   Jalankan `loader_soil_builder.lua`.

---
Dikembangkan oleh **Boren Store** / **rendhi69**.
