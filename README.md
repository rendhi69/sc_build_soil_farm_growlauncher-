# SC Build Soil Farm GrowLauncher - Boren Store

Script otomatis pembuatan layout soil / block farm untuk GrowLauncher (Growtopia Bot).
Mendukung susunan horizontal rows & water elevator, struktur lock enclosure baru, 3 kategori world management terpisah, mode put 3 block zigzag cepat, dan integrasi database item resmi Growtopia / Lucifer.

## Fitur Utama & Perbaikan V2.6.2
1. **Solusi Siklus START / STOP & Antrean World (Re-Run Bebas Macet):**
   - **Reset Status Otomatis ke ANTRI:** Saat bot dihentikan manual atau tombol STOP ditekan, status world yang sedang berlangsung (`PROSES`) langsung dikembalikan ke `ANTRI` (tidak berubah jadi `GAGAL`), sehingga world dapat langsung di-run kembali saat START ditekan.
   - **Auto-Sync Start/Stop Multi-Button:** Ditambahkan tombol instan `▶ START SOIL BOT` (`sb_btn_start`) dan `■ STOP SOIL BOT` (`sb_btn_stop`) di samping toggle `▶ START / ■ STOP TOGGLE` (`sb_run_power`).
   - **Proteksi Desync Toggle ImGui GL:** Logika penanganan event toggle kini mendeteksi kondisi bot; jika bot sedang berhenti dan widget toggle diklik (meskipun ImGui mengirimkan angka 0 karena desync), bot tetap **dipastikan langsung START**.
   - **Pemilihan World Undone Komprehensif:** Saat tombol START ditekan, seluruh world yang belum selesai (`not done and status ~= "DONE"`) otomatis di-reset menjadi `ANTRI` dan diproses secara berurutan tanpa ada world yang terlewati.
   - **Coroutine Non-Blocking (`CSleep`):** Menggunakan `CSleep` pada coroutine runtime untuk respons jeda/stop instan tanpa freeze.
2. **Posisi Baris Block Presisi Standar Soil Farm (27 Baris di Y Ganjil 1..53):**
   - **Baris Paling Bawah (Y=53):** Terletak persis di atas Bedrock (Y=54), **sejajar dengan World Lock dan Signal Jammer**.
   - **Baris Paling Atas (Y=1):** Memiliki **ruang tanam (space for planting) di Y=0 yang sejajar persis dengan Door ID (0,0)**.
   - Koreksi baris ganjil 1..53 (step 2, total 27 baris).
3. **Perbaikan Tuntas Dialog & Re-apply Lock (SL, WL, Door ID):**
   - **Small Lock Re-apply:** Selalu mengirim paket dialog resmi `buttonClicked|recalcLock` dan `checkbox_ignore|1` dengan `tilex`/`tiley` eksplisit.
   - **World Lock Public:** Selalu mengirim paket `checkbox_public|1` dengan `tilex`/`tiley` eksplisit.
   - **Door ID (0,0):** Selalu mengirim konfigurasi Door ID (`door_id`), Label (`door_name`), dan `checkbox_locked|1` (open to public).
   - Validasi struktur kunci: jika WL, SL, Jammer, dan Blocker sudah terpasang, bot melewati pemecahan/pemasangan ulang dan langsung memverifikasi Small Lock & Door ID.
4. **Mode Put 3 Block (Zigzag Cepat Ala Lucifer):**
   - Menempatkan 3 block sekaligus dari satu posisi berdiri di koridor udara `(standX, y - 1)`: `{ standX - 1, standX, standX + 1 }`.
   - Melangkah 3 petak ke depan secara dinamis (`step 3`), mempercepat penempatan block hingga ~3x lipat dibanding mode 1-by-1 biasa.
   - Dilengkapi toggle di UI tab Pengaturan: `Mode Put 3 Block (Zigzag Cepat)` (default: ON / `3zigzag`, dengan fallback `1by1`).
5. **Layout Grid Presisi Sesuai Standar Soil Farm:**
   - **Kolom X=0:** Kolom air (Water Elevator) vertikal dari Y=1 s/d Y=54.
   - **Kolom X=1 s/d X=98:** Baris horizontal Soil Block (27 baris di Y ganjil: 1, 3, 5, ..., 53). Baris langsung menempel rapi di sebelah kolom air (`row_start_x = 1`).
   - **Kolom X=99:** Selalu KOSONG (Air Corridor) dari atas ke bawah sebagai akses jalur lewat/terjun bot & player (`row_end_x = 98`).
6. **Sinkronisasi Database Item Resmi (Standar Lucifer / Growtopia items.dat):**
   - **Air Vent:** ID 2810.
   - **Water Bucket:** ID 822.
   - **Door / Wooden Door:** ID 12.
   - **Wooden Platform:** ID 102.
   - **Dungeon Door:** ID 30.
   - **House Entrance:** ID 224.
   - **Screen Door:** ID 858.
   - **Portcullis:** ID 60.
   - **Orange Portal:** ID 544.
   - **Cave Blast:** ID 3562.
7. **Formasi & Urutan Lock Enclosure Baru Sesuai Standar Farm:**
   - **Urutan Pemasangan:**
     1. **Penghalang (Air Vent 2810 / Door 12)** di atas White Door: `(doorX, doorY - 1)` (di sebelah kanan Small Lock).
     2. **Signal Jammer (ID 226)** di kiri White Door: `(doorX - 1, doorY)` + punch 1x (aktif).
     3. **Small Lock (ID 202)** di atas Jammer / kiri Penghalang: `(doorX - 1, doorY - 1)` + re-apply lock (ignore air = 1, private = 0, meng-cover Jammer & Penghalang).
     4. **World Lock (ID 242)** di sebelah kiri Jammer: `(doorX - 2, doorY)` + set ke Public.
     5. **Door ID (ID 12)** di koordinat `(0, 0)` + konfigurasi Door ID & Label.
8. **Pemisahan 3 Kategori World Terorganisir:**
   - **World Put (Antrean Farm):** Daftar world farm tujuan yang akan dibangun (`boren_soil_worlds.txt`).
   - **World Gudang Alat:** Khusus restock World Lock, Small Lock, Signal Jammer, dan Wooden Door (`boren_soil_tools.txt`).
   - **World Gudang Block:** Khusus restock Soil Block ID 8772 (`boren_soil_blocks.txt`).

## Cara Menggunakan (Loader)
Jalankan file `loader.lua` atau `loader_soil_builder.lua` di GrowLauncher.
Loader akan otomatis mengunduh skrip terbaru dari repositori ini.
