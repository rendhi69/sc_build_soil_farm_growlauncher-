# SC Build Soil Farm GrowLauncher - Boren Store

Script otomatis pembuatan layout soil / block farm untuk GrowLauncher (Growtopia Bot).
Mendukung susunan horizontal rows & water elevator, struktur lock enclosure baru, 3 kategori world management terpisah, mode put 3 block zigzag cepat, dan integrasi database item resmi Growtopia / Lucifer.

## Fitur Utama V2.4.0
1. **Mode Put 3 Block (Zigzag Cepat Ala Lucifer):**
   - Menempatkan 3 block sekaligus dari satu posisi berdiri di koridor udara `(standX, y - 1)`: `{ standX - 1, standX, standX + 1 }`.
   - Melangkah 3 petak ke depan secara dinamis (`step 3`), mempercepat penempatan block hingga ~3x lipat dibanding mode 1-by-1 biasa.
   - Dilengkapi toggle di UI tab Pengaturan: `Mode Put 3 Block (Zigzag Cepat)` (default: ON / `3zigzag`, dengan fallback `1by1`).
2. **Layout Grid Presisi Sesuai Standar Soil Farm:**
   - **Kolom X=0:** Kolom air (Water Elevator) vertikal dari Y=1 s/d Y=54.
   - **Kolom X=1 s/d X=98:** Baris horizontal Soil Block (27 baris di Y genap: 2, 4, 6, ..., 54). Baris langsung menempel rapi di sebelah kolom air (`row_start_x = 1`).
   - **Kolom X=99:** Selalu KOSONG (Air Corridor) dari atas ke bawah sebagai akses jalur lewat/terjun bot & player (`row_end_x = 98`).
3. **Sinkronisasi Database Item Resmi (Standar Lucifer / Growtopia items.dat):**
   - **Air Vent:** ID 2810 (bukan 828).
   - **Water Bucket:** ID 822 (bukan 818).
   - **Door / Wooden Door:** ID 12 (bukan 102).
   - **Wooden Platform:** ID 102 (bukan 458).
   - **Dungeon Door:** ID 30 (bukan 540 / 778).
   - **House Entrance:** ID 224 (bukan 1240 / 492).
   - **Screen Door:** ID 858 (bukan 558 / 886).
   - **Portcullis:** ID 60 (bukan 16 / 1032).
   - **Orange Portal:** ID 544 (bukan 382 / 766).
   - **Cave Blast:** ID 3562 (bukan 2810).
   - Dilengkapi database JSON `items_database.json` di repositori ini.
4. **Formasi & Urutan Lock Enclosure Baru Sesuai Standar Farm:**
   - **Urutan Pemasangan:**
     1. **Penghalang (Air Vent 2810 / Door 12)** di atas White Door: `(doorX, doorY - 1)` (di sebelah kanan Small Lock).
     2. **Signal Jammer (ID 226)** di kiri White Door: `(doorX - 1, doorY)` + punch 1x (aktif).
     3. **Small Lock (ID 202)** di atas Jammer / kiri Penghalang: `(doorX - 1, doorY - 1)` + re-apply lock (ignore air = 1, private = 0, meng-cover Jammer & Penghalang).
     4. **World Lock (ID 242)** di sebelah kiri Jammer: `(doorX - 2, doorY)` + set ke Public.
     5. **Door ID (ID 12)** di koordinat `(0, 0)` + konfigurasi Door ID & Label.
5. **Pemisahan 3 Kategori World Terorganisir:**
   - **World Put (Antrean Farm):** Daftar world farm tujuan yang akan dibangun (`boren_soil_worlds.txt`).
   - **World Gudang Alat:** Khusus restock World Lock, Small Lock, Signal Jammer, dan Wooden Door (`boren_soil_tools.txt`).
   - **World Gudang Block:** Khusus restock Soil Block ID 8772 (`boren_soil_blocks.txt`).
6. **Penyempurnaan Pre-Flight Inventory & Deteksi Multi-Tier:**
   - 3-tier inventory scanning (memory userdata -> string conversion -> authoritative `growtopia.checkInventory`).
   - Pengambilan alat & block otomatis ke gudang sebelum memulai pembangunan.

## Cara Menggunakan (Loader)
Jalankan file `loader.lua` atau `loader_soil_builder.lua` di GrowLauncher.
Loader akan otomatis mengunduh skrip terbaru dari repositori ini.
