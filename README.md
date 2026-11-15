# SC Build Soil Farm GrowLauncher - Boren Store

Script otomatis pembuatan layout soil / block farm untuk GrowLauncher (Growtopia Bot).
Mendukung susunan horizontal rows & water elevator, struktur lock enclosure baru, dan 3 kategori world management terpisah.

## Fitur Utama V2.3.1
1. **Formasi & Urutan Lock Enclosure Baru Sesuai Standar Farm:**
   - **Urutan Pemasangan:**
     1. **Penghalang (Air Vent / Door)** di atas White Door: `(doorX, doorY - 1)` (di sebelah kanan Small Lock).
     2. **Signal Jammer (ID 226)** di kiri White Door: `(doorX - 1, doorY)` + punch 1x (aktif).
     3. **Small Lock (ID 202)** di atas Jammer / kiri Penghalang: `(doorX - 1, doorY - 1)` + re-apply lock (ignore air = 1, private = 0, meng-cover Jammer & Penghalang).
     4. **World Lock (ID 242)** di sebelah kiri Jammer: `(doorX - 2, doorY)` + set ke Public.
     5. **Door ID (ID 12)** di koordinat `(0, 0)` + konfigurasi Door ID & Label.
2. **Jalur Lewat Vertikal Bebas Hambatan (Kolom 99 Kosong):**
   - Baris soil block secara otomatis di-clamp maksimal di `x = 98` (`row_end_x = 98`).
   - Kolom paling kanan (`x = 99`) selalu dibiarkan kosong (air) dari atas ke bawah sebagai koridor jatuh/lompat pemain dan bot.
3. **Pemisahan 3 Kategori World Terorganisir:**
   - **World Put (Antrean Farm):** Daftar world farm tujuan yang akan dibangun (`boren_soil_worlds.txt`).
   - **World Gudang Alat:** Khusus restock World Lock, Small Lock, Signal Jammer, dan Wooden Door (`boren_soil_tools.txt`).
   - **World Gudang Block:** Khusus restock Soil Block ID 8772 (`boren_soil_blocks.txt`).
   - Tombol **📍 Tambah World Sekarang** untuk mendaftarkan world tempat bot berada saat ini secara instan ke masing-masing kategori.
4. **Penyempurnaan Pre-Flight Inventory & Deteksi Multi-Tier:**
   - 3-tier inventory scanning (memory userdata -> string conversion -> authoritative `growtopia.checkInventory`).
   - Pengambilan alat & block otomatis ke gudang sebelum memulai pembangunan.
5. **Kolom Water Elevator Vertikal:**
   - Penempatan vertikal water di Tile X=0 (Y=1 s/d 54) untuk fast swimming elevator.
6. **Pola Baris Block / Soil:**
   - Penempatan horizontal baris block per step 2 (Y genap: 2, 4, 6... 54) secara sinuous.

## Cara Menggunakan (Loader)
Jalankan file `loader.lua` atau `loader_soil_builder.lua` di GrowLauncher.
Loader akan otomatis mengunduh skrip terbaru dari repositori ini.
