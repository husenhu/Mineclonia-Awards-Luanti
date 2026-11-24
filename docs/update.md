Berikut idenya, dari level terendah (1) hingga tertinggi (9):

### 🌱 Level 1–3: Efek Dasar (Subtle & Natural)

Level rendah sebaiknya menggunakan partikel kecil, sedikit, dan bertekstur "alam" seperti tanah, pasir, atau batu.

- **Level 1 — Debu Tanah**: Partikel sangat kecil dan jarang, muncul sesekali di sekitar kaki. Gunakan `node = {name = "mcl_core:dirt"}` dengan `amount` rendah (misal 2–3), `size` kecil, dan `blend = "alpha"` (default). Efek ini seperti karakter yang baru berjalan di tanah kering.
- **Level 2 — Percikan Pasir**: Sedikit lebih banyak, dengan ukuran partikel bervariasi. Gunakan `texpool` berisi `"mcl_core:sand"` dan `"mcl_core:gravel"` agar warna partikelnya acak. Tambahkan `velocity` kecil agar partikel sedikit memancar ke atas.
- **Level 3 — Serpihan Batu**: Partikel sedikit lebih besar dan lebih sering. Gunakan `node = {name = "mcl_core:cobble"}` atau `"mcl_core:stone"`. Mulai gunakan `collisiondetection = true` agar partikel memantul di tanah, memberi kesan "pecahan" yang jatuh.

### ✨ Level 4–6: Efek Menengah (Mulai Terlihat "Magis")

Di level ini, mulai eksplorasi `blend` mode dan `glow` untuk memberi kesan energi atau sihir, tetapi tetap dengan tekstur blok yang sudah ada.

- **Level 4 — Kilau Mineral**: Gunakan tekstur blok yang agak berkilau seperti `"mcl_core:ironblock"` atau `"mcl_core:goldblock"`. Atur `blend = "add"` agar partikel tampak menyala redup. Jumlah partikel sedang, dan beri `glow = 5` agar sedikit bersinar di tempat gelap.
- **Level 5 — Energi Kristal**: Campur tekstur `"mcl_core:diamondblock"` dan `"mcl_core:emeraldblock"` menggunakan `texpool`. Gunakan `blend = "add"`, `glow = 8`, dan `scale_tween` agar partikel mengecil seiring waktu (efek "menyerap" energi).
- **Level 6 — Aura Api**: Gunakan `node = {name = "mcl_core:lava"}`? Hati-hati, lava adalah cairan; lebih aman gunakan blok padat seperti `"mcl_core:magma"` (jika ada) atau `"mcl_core:redstoneblock"`. Atur `blend = "add"`, `glow = 12`, dan `velocity` ke atas agar partikel seperti nyala api yang naik.

### 🔥 Level 7–9: Efek Tinggi (Epik & Berlapis)

Level tertinggi sebaiknya menggunakan beberapa spawner sekaligus, atau `texpool` yang kaya, dengan parameter ekstrem (glow tinggi, blend aditif, ukuran besar).

- **Level 7 — Badai Petir**: Gunakan `texpool` berisi `"mcl_core:goldblock"` (untuk kilatan) dan `"mcl_core:stone"` (untuk debu). Beberapa spawner dengan `amount` tinggi, `glow = 14`, dan `blend = "add"`. Tambahkan `collisiondetection = true` agar partikel menghantam tanah.
- **Level 8 — Aura Dewa**: Gunakan `node = {name = "mcl_core:diamondblock"}` dengan `size` besar, `glow = 15`, dan `blend = "add"`. Tambahkan `radius` pada spawner agar partikel tersebar dalam bola di sekitar karakter, bukan hanya di kaki. Efeknya seperti aura kristal yang berputar.
- **Level 9 — Supernova**: Gabungkan **tiga spawner** sekaligus:
    1.  Spawner inti: `node = {name = "mcl_core:glowstone"}` (atau `"mcl_core:sea_lantern"` jika ada), `glow = 15`, `blend = "add"`, `size` sangat besar.
    2.  Spawner lingkaran: `texpool` berisi `"mcl_core:goldblock"` dan `"mcl_core:diamondblock"`, `radius` lebar, `amount` tinggi.
    3.  Spawner percikan: partikel kecil dengan `velocity` ke segala arah, `collisiondetection = true`.
    
    Ini menciptakan efek ledakan energi yang spektakuler, semuanya dari tekstur blok vanilla Mineclonia.

### 💡 Tips Tambahan

- **`attached`**: Jangan lupa mengisi `attached = player` (objek pemain) pada setiap spawner agar partikel mengikuti karakter, bukan tertinggal di satu titik.
- **`playername`**: Jika efek hanya untuk pemain tertentu (misal buff personal), isi `playername` agar partikel hanya muncul di klien pemain tersebut.
- **`node_tile`**: Untuk kontrol lebih detail, Anda bisa menentukan `node_tile` (1–6) untuk memilih sisi tekstur blok tertentu, misalnya hanya bagian atas rumput.

Dengan pendekatan ini, Anda bisa membuat gradasi efek dari "debu biasa" hingga "aura dewa" hanya dengan mengubah parameter partikel dan memilih tekstur blok yang sudah ada di Mineclonia. Selamat bereksperimen!