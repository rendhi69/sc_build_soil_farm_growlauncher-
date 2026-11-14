# SC Build Soil Farm GrowLauncher - Boren Store

Script otomatis pembuatan layout soil / block farm untuk GrowLauncher (Growtopia Bot).
Mendukung susunan horizontal rows & water elevator, struktur lock enclosure baru, dan 3 kategori world management terpisah.

## Fitur Utama V2.3.0
1. **Pemisahan 3 Kategori World Terorganisir:**
   - **World Put (Antrean Farm):** Daftar world farm tujuan yang akan dibangun (`boren_soil_worlds.txt`).
   - **World Gudang Alat:** Khusus restock World Lock, Small Lock, Signal Jammer, dan Wooden Door (`boren_soil_tools.txt`).
   - **World Gudang Block:** Khusus restock Soil Block ID 8772 (`boren_soil_blocks.txt`).
   - Tombol **📍 Tambah World Sekarang** untuk mendaftarkan world tempat bot berada saat ini secara instan ke masing-masing kategori.
2. **Formasi Lock Enclosure & Door ID (0, 0):**
   - Formasi pintu masuk:
     - White Door di `(doorX, doorY)`.
     - Signal Jammer (ID 226) di `(doorX - 1, doorY)` + punch aktif 1x.
     - Small Lock (ID 202) di `(doorX - 1, doorY - 1)` + recalc lock (ignore air = 1, private = 0).
     - World Lock (ID 242) di `(doorX - 2, doorY)` + set public.
     - Wooden Door (ID 12) di koordinat `(0, 0)` seperti Dirt Farm (DF) + setting Door ID.
   - Proteksi kunci default aktif (`enable_lock_enclosure = true`).
3. **Penyempurnaan Warp & Deteksi World:**
   - Standardisasi `getWorldNameSafe()` menggunakan `getCurrentWorldName()` bawaan GrowLauncher.
   - Deteksi White Door dengan polling hingga 15 kali untuk memastikan tile world selesai terunduh.
4. **Pre-Flight Inventory Restock:**
   - Pengecekan tas otomatis sebelum masuk ke world farm. Jika alat atau block kurang, bot langsung mengambil ke gudang masing-masing terlebih dahulu.
5. **Kolom Water Elevator Vertikal:**
   - Penempatan vertikal water di Tile X=0 (Y=1 s/d 54) untuk fast swimming elevator.
6. **Pola Baris Block / Soil:**
   - Penempatan horizontal baris block per step 2 (Y genap: 2, 4, 6... 54) secara sinuous.
   - Default ID Block 8772 (Soil Block).

## Cara Menggunakan (Loader)
Jalankan file `loader.lua` atau `loader_soil_builder.lua` di GrowLauncher.
Loader akan otomatis mengunduh skrip terbaru dari repositori ini.
