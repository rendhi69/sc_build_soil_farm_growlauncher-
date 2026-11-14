# SC Build Soil Farm GrowLauncher

Script otomatis pembuatan layout soil / block farm untuk GrowLauncher (Growtopia Bot).
Sesuai layout horizontal rows & water elevator (Gambar 1) dan struktur lock enclosure (Gambar 2).

## Fitur Utama
1. **Auto Blast & Random World Search (Opsional):**
   - Mendukung pencarian world acak (huruf/angka/prefix).
   - Penggunaan otomatis item blast (World Blast ID 1336 / Cave Blast ID 2810).
2. **Lock Enclosure (Sesuai Gambar 2):**
   - Penempatan terpadu: Wooden Door (Door ID), Small Lock, Air Vent / Blocker Door, World Lock, Signal Jammer di sekitar White Door.
   - Otomatis recalc lock & setting door ID.
3. **Kolom Water Elevator (Sesuai Gambar 1):**
   - Penempatan vertikal water di Tile X=0 (Y=1 s/d 54) untuk fast swimming elevator.
4. **Pola Baris Block / Soil (Sesuai Gambar 1):**
   - Penempatan horizontal baris block per step 2 (Y genap: 2, 4, 6... 54) secara sinuous.
   - Pilihan ID Block fleksibel (Dirt 2, Soil/Mars Rock 100, Wood Platform 102, dll.).
5. **Multi-Storage Restock Engine:**
   - Otomatis warp ke daftar gudang saat block di tas menipis (< threshold), memungut floating block, dan kembali ke titik kerja.
6. **Manajemen Antrean World & File Permanen:**
   - Unified Dialog Manager untuk input / tempel / salin antrean world & storage.
   - Cadangan file otomatis di folder Download perangkat (`boren_soil_worlds.txt` dan `boren_soil_storages.txt`).

## Cara Menggunakan (Loader)
Jalankan file `loader.lua` atau `loader_soil_builder.lua` di GrowLauncher.
Loader akan otomatis mengambil skrip terbaru dari repositori ini.
