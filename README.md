# LyricFloat

Aplikasi macOS untuk bernyanyi mengikuti musik dengan lirik bertimestamp di jendela mengambang. Sumber utama adalah **YouTube dan YouTube Music di browser**, dengan dukungan tambahan untuk Apple Music, Spotify desktop, dan audio lokal.

![Ikon LyricFloat](Assets/AppIcon.iconset/icon_128x128.png)

## Fitur

- Lirik aktif ditandai dan otomatis mengikuti waktu pemutaran.
- Jendela dapat tetap berada di atas aplikasi lain.
- Mode mini menampilkan lirik saat ini dan baris sebelumnya/berikutnya yang pudar, dengan latar kaca transparan.
- Drag otomatis mengubah jendela menjadi mini. Klik untuk kembali ke tampilan lengkap.
- Sudut posisi dipertahankan saat ukuran berubah; default kiri atas, termasuk dukungan posisi kiri bawah.
- Kontrol pause/play, timeline, lompat lima detik, dan klik lirik untuk seek.
- Pencarian lirik dari LRCLIB serta impor file `.lrc`.
- Pencocokan otomatis memilih durasi terdekat, dengan selisih maksimal **5 detik** dan pemeriksaan judul/artis. Versi lain dapat dipilih manual.

Lirik disinkronkan per baris, bukan per kata. Video live, cover, remix, dan versi berbeda bisa membutuhkan lirik lain atau penyesuaian waktu.

## Persyaratan

- **macOS 13 atau lebih baru.**
- Apple Silicon atau Intel untuk paket **universal** dari CI.
- Chrome, Brave, Edge, atau browser Chromium lain untuk koneksi YouTube.
- Internet untuk pencarian lirik; audio lokal dengan file LRC dapat dipakai tanpa pencarian online.

Safari dan Spotify versi web belum didukung. Tidak perlu akun LyricFloat atau API key LRCLIB.

## Download dari GitHub Actions

Setelah perubahan di-merge atau di-push ke branch `main`:

1. Buka repository di GitHub → **Actions → Build LyricFloat**.
2. Pilih workflow dengan status berhasil.
3. Pada bagian **Artifacts**, download:

   | File | Isi |
   | --- | --- |
   | `LyricFloat-macos-universal.zip` | `LyricFloat.app`, mendukung Apple Silicon dan Intel |
   | `LyricFloat-browser-extension.zip` | Ekstensi YouTube; `manifest.json` berada di root ZIP |
   | `SHA256SUMS` | Checksum SHA-256 kedua ZIP |

Artifact tersedia selama **30 hari** dan download melalui Actions membutuhkan login GitHub serta akses ke repository. Untuk unduhan publik tanpa login yang permanen, gunakan GitHub Releases; workflow ini belum menerbitkan Releases.

## Instalasi aplikasi

1. Ekstrak `LyricFloat-macos-universal.zip`.
2. Pindahkan **LyricFloat.app** ke folder **Applications**.
3. Buka aplikasi.

**Paket CI saat ini ditandatangani secara ad-hoc dan belum dinotariskan Apple.** macOS dapat menolak aplikasi yang diunduh. Untuk distribusi umum yang lancar, maintainer perlu menambahkan Developer ID signing dan notarization. Workflow sekarang tidak memerlukan sertifikat atau secret tambahan. Lihat [panduan distribusi Apple](https://developer.apple.com/developer-id/).

Pengguna tidak perlu memasang Xcode, Swift, Node.js, atau Python untuk menjalankan paket yang sudah dibangun.

## Pasang ekstensi dan hubungkan YouTube

1. Ekstrak `LyricFloat-browser-extension.zip` ke folder permanen, misalnya `Documents/LyricFloatExtension`. Jangan hapus folder ini setelah instalasi.
2. Buka halaman ekstensi browser:
   - Chrome: `chrome://extensions`
   - Brave: `brave://extensions`
   - Edge: `edge://extensions`
3. Aktifkan **Developer mode**, pilih **Load unpacked**, lalu pilih folder yang berisi `manifest.json`.
4. Pada LyricFloat, pilih **Connect YouTube** atau **Connect browser…**, lalu salin pairing code.
5. Buka popup ekstensi LyricFloat, tempel kode, dan pilih **Save connection**.
6. Reload tab YouTube/YouTube Music dan putar lagu.

Ekstensi juga dibundel di dalam aplikasi. **Connect browser → Show browser extension folder** akan menampilkan foldernya.

Pairing code dibuat otomatis di setiap Mac. Kode ini hanya menghubungkan browser ke aplikasi lokal, bukan token akun LRCLIB, YouTube, atau akun developer. Jangan memakai kode dari Mac pengguna lain.

Jika beberapa tab YouTube terbuka, ekstensi mengikuti tab pemutaran yang dipilih otomatis. Gunakan **Follow this YouTube tab** untuk mengunci satu tab, atau **Auto-select tab** untuk kembali ke pemilihan otomatis. Menutup tab yang dikunci menghapus pilihan tersebut.

Ekstensi membaca posisi, durasi, status pemutaran, kecepatan, judul, dan channel/artis dari browser. Saat iklan tampil, lirik dijeda. Jika update browser berhenti, aplikasi berhenti memperkirakan waktu setelah tiga detik.

## Sumber musik lain

Pilih sumber dari menu di bagian atas jendela:

- **Apple Music:** buka aplikasi Music dan putar lagu. Berikan izin Automation ketika diminta macOS.
- **Spotify:** gunakan aplikasi Spotify desktop dan berikan izin Automation.
- **Local audio:** pilih **Open local audio…**. File `.lrc` dengan nama yang sama di sebelah file audio dimuat otomatis.
- **Demo:** contoh lirik orisinal tanpa audio untuk mencoba tampilan.

Izin Music/Spotify dapat diatur di **System Settings → Privacy & Security → Automation**. Adapter menggunakan antarmuka AppleScript aplikasi desktop; dukungan aktual bergantung pada aplikasi dan format audionya.

## Memilih lirik dan mengatur waktu

Hasil pencarian menampilkan durasi lagu dan selisih terhadap pemutaran saat ini. Lirik bertimestamp diurutkan lebih dulu, lalu versi dengan durasi terdekat. Jika judul/artis atau durasi tidak cukup cocok, aplikasi tidak memasang lirik otomatis; pilih melalui **Find lyrics**.

- **− / +:** ubah jeda lirik per 0,5 detik, sampai ±120 detik. Nilai positif menampilkan lirik lebih lambat, berguna untuk intro video.
- **Space:** pause/play ketika jendela memiliki fokus.
- **Pin:** aktifkan atau matikan always-on-top.
- **Options:** ubah ukuran teks, impor LRC, buka audio, atau quit.
- Menutup jendela tetap membiarkan aplikasi berjalan. Klik ikon Dock untuk membukanya kembali; gunakan **Quit LyricFloat** untuk menghentikan aplikasi.

Untuk impor manual, gunakan LRC UTF-8:

```text
[ar:Artist]
[ti:Song]
[00:12.50]The first line
[00:18.00]The next line
[00:24.00][00:48.00]A repeated chorus
```

Timestamp pecahan, beberapa timestamp per baris, dan `[offset:milliseconds]` didukung. Baris kosong bertimestamp menunjukkan jeda instrumental. Lirik tanpa timestamp dapat dibaca, tetapi tidak mengikuti posisi pemutaran.

## Privasi dan sumber data

- Lirik dicari dari [LRCLIB](https://lrclib.net/docs), layanan publik. Implementasi pencarian ini tidak memakai akun atau API key.
- Query judul/artis dikirim ke LRCLIB saat pencarian. Metadata pemutaran untuk koneksi browser dikirim hanya ke aplikasi di Mac yang sama.
- Koneksi lokal mendengarkan pada `127.0.0.1:18473`, dengan pairing code per instalasi. Hanya satu instance aplikasi dapat memakai port tersebut.
- Ekstensi hanya berjalan di YouTube/YouTube Music, dengan akses tambahan ke localhost untuk komunikasi aplikasi.
- Tidak ada analytics atau login aplikasi. Mengimpor LRC membatalkan pencarian yang masih berlangsung.
- API publik tidak membuktikan bahwa seluruh konten lirik memiliki izin redistribusi atau penggunaan komersial. Jangan menganggap lisensi kode server LRCLIB sebagai lisensi seluruh lirik.

## Build lokal

Untuk pengembang: gunakan macOS, Xcode dengan Swift **5.9 atau lebih baru**, serta Python 3 untuk packaging. Node.js **22 atau lebih baru** dipakai untuk tes ekstensi. Tidak ada dependency Swift pihak ketiga atau paket npm yang harus dipasang.

Build untuk arsitektur Mac saat ini:

```sh
./scripts/build-app.sh
open dist/LyricFloat.app
```

Build universal untuk Apple Silicon dan Intel:

```sh
./scripts/build-app.sh --universal
```

Build sekaligus ZIP aplikasi, ZIP ekstensi, dan checksum:

```sh
./scripts/package-release.sh --universal
```

Hasil berada di `dist/packages/`. Tanpa `--universal`, nama paket mengikuti arsitektur build: `arm64` atau `intel`.

Build dilakukan dalam folder sementara, diverifikasi, lalu menggantikan bundle aplikasi. Bundle sebelumnya disimpan di folder tersembunyi dalam `dist` agar executable yang sedang berjalan tidak ditimpa. Quit dan buka ulang aplikasi setelah rebuild.

## CI/CD GitHub

Workflow: [`.github/workflows/build.yml`](.github/workflows/build.yml).

| Pemicu | Perilaku |
| --- | --- |
| Merge atau push ke `main` | Tes, build universal `.app`, package ekstensi, verifikasi, upload artifact |
| Pull request menuju `main` | Tes dan build untuk validasi; artifact tidak di-upload |
| Actions → Run workflow | Menjalankan build manual pada branch yang dipilih |

Workflow menggunakan runner `macos-15` dan Node.js 24. Tahapannya:

1. Checkout kode.
2. Jalankan tes Swift, termasuk bridge localhost, dan tes JavaScript ekstensi.
3. Build release untuk `arm64` + `x86_64`.
4. Buat bundle `.app`, tanda tangani ad-hoc, dan kemas ZIP aplikasi/ekstensi.
5. Periksa arsitektur universal, signature, plist, isi archive, izin executable, dan resource ekstensi.
6. Upload dua ZIP serta checksum dengan masa simpan 30 hari.

Tidak perlu menambahkan GitHub Secrets untuk pipeline ini. GitHub menyediakan kredensial otomatis untuk menjalankan Actions; kredensial tersebut tidak dibundel ke aplikasi. Workflow hanya meminta permission `contents: read`.

Untuk mengaktifkan CI, masukkan project ini ke repository GitHub dengan branch `main`, pastikan folder `.github` ikut di-commit, dan aktifkan GitHub Actions pada repository. Sertakan `Package.swift`, `Sources`, `Tests`, `Assets`, `BrowserExtension`, `scripts`, README, dan `.gitignore`; jangan commit `.build*` atau `dist`.

Workflow ini menghasilkan paket download, bukan deployment ke App Store, Chrome Web Store, atau GitHub Releases. Untuk rilis aplikasi yang dinotariskan perlu konfigurasi signing tambahan. [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [artifact uploads](https://github.com/actions/upload-artifact).

## Tes

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache" \
swift test --disable-sandbox --scratch-path .build

node --test Tests/BrowserExtensionTests/*.test.cjs
```

Tes mencakup LRC, batas timestamp, seek, pause/iklan, perubahan lagu playlist, metadata YouTube terlambat, pencocokan durasi, sudut penempatan jendela, autentikasi bridge lokal, pemilihan tab, dan penolakan perintah lama setelah pergantian lagu. Pemutaran nyata dan tampilan pada versi macOS berbeda tetap perlu diuji manual.

## Troubleshooting

- **YouTube tidak terhubung:** buka aplikasi, cek pairing code, reload ekstensi dan tab YouTube. Pastikan tidak ada instance LyricFloat lain memakai port yang sama.
- **Lirik salah atau tidak ditemukan:** gunakan **Find lyrics**, periksa versi/durasi, atau impor LRC. Nama channel bukan selalu nama artis.
- **Lirik terlambat/terlalu cepat:** sesuaikan tombol **− / +**. Versi rekaman berbeda bisa membutuhkan LRC lain.
- **Setelah update:** quit dan buka ulang aplikasi; reload ekstensi pada halaman Extensions, kemudian reload YouTube. Pairing ulang hanya jika kode berubah.
- **Workflow tidak muncul:** pastikan `.github/workflows/build.yml` ada di repository dan GitHub Actions diaktifkan.
- **Artifact hilang:** pilih run yang berhasil pada `main`; artifact kedaluwarsa setelah 30 hari. Jalankan workflow lagi untuk paket baru.

## Struktur project

- `Sources/LyricFloat`: jendela SwiftUI/AppKit, audio lokal, pencarian, adapter Music/Spotify.
- `Sources/LyricCore`: LRC, pencocokan durasi, identitas lagu, geometri jendela, bridge lokal.
- `BrowserExtension`: ekstensi Chromium, popup pairing, dan ikon.
- `Assets`: ikon aplikasi `.icns` dan ukuran sumber PNG.
- `Tests`: tes Swift dan JavaScript.
- `scripts/build-app.sh`: build native/universal dan bundle aplikasi.
- `scripts/package-release.sh`: paket ZIP dan checksum.
- `scripts/verify-release.py`: verifikasi isi paket.
- `.github/workflows/build.yml`: otomatisasi GitHub Actions.
