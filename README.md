# Tannhäuser Music Player

**Bit-perfect USB Audio Player untuk Android** berbasis arsitektur hybrid (**Flutter + Kotlin + C++ NDK**).  
Dirancang untuk mem-bypass mixer bawaan Android (`AudioFlinger`) dan mengirimkan aliran PCM mentah langsung ke USB DAC eksternal melalui `libusb` dan `FFmpeg`.

---

## Arsitektur Hybrid (Zero Mixer Policy)

Aplikasi ini menerapkan pemisahan tanggung jawab secara ketat (tanpa menggunakan `OpenSL ES`, `Oboe`, `AAudio`, maupun package pemutar audio `pub.dev`):

1. **Flutter / Dart (`lib/`) — UI & State Only**
   - Bertanggung jawab penuh atas antarmuka pengguna bertema *EVA-01 Tactical Audio Terminal* (arsitektur layar **Lean 3+3**), manajemen antrean, kurva PEQ, dan komunikasi Platform Channel melalui [`NativeAudioService`](lib/services/native_audio_service.dart).
2. **Kotlin / Android (`android/app/src/main/kotlin/...`) — System & Hardware Bridge**
   - `UsbBridge.kt`: Deteksi perangkat USB Audio Class (UAC 1.0/2.0), permintaan izin USB runtime (`PendingIntent`), dan pengambilan File Descriptor (`fd`).
   - `NativeAudioBridge.kt`: Seluruh pemanggilan JNI dijalankan pada background `SingleThreadExecutor` untuk mencegah ANR.
   - `AudioPlaybackService.kt`: Android Foreground Service (`mediaPlayback`) dengan `MediaSessionCompat` untuk menjaga thread audio tetap hidup saat layar mati serta kontrol notifikasi/lockscreen.
   - `FileScanner.kt`: Direct filesystem & SD Card crawler (`StorageManager` + `MANAGE_EXTERNAL_STORAGE`).
   - `MainActivity.kt`: Handler `MethodChannel` / `EventChannel` serta intersepsi tombol volume fisik saat USB DAC aktif.
3. **C++ NDK (`android/app/src/main/cpp/`) — Core Audio & USB Engine**
   - `AudioDecoder` (`engine/audio_decoder.cpp`): Dekoding audio berbasis FFmpeg (`FLAC`, `WAV`, `ALAC`, `M4A`, `AAC`, `MP3`) serta header-only prober (`probeAudioFile`) tanpa alokasi codec context penuh.
   - `PeqEngine` (`engine/peq_engine.cpp`): Parametric Equalizer 64-bit double-precision (hingga 10 band biquad TDF-II: `PK`, `LS`, `HS`, `LP`, `HP`), pre-amp attenuation, TPDF dither, lock-free double-buffered coefficient swap, dan **pure bit-perfect bypass** saat nonaktif.
   - `UsbDriver` (`engine/usb_driver.cpp`): Integrasi `libusb_wrap_sys_device` dengan `LIBUSB_OPTION_NO_DEVICE_DISCOVERY` (SELinux Netlink bypass), parsing deskriptor UAC1/UAC2 dinamis, sinkronisasi hardware clock, transfer asinkron Isochronous/Bulk (pacing 8000 microframe/detik), dan auto-padding subslot 32-bit.
   - `RingBuffer` (`engine/ring_buffer.h`): Lock-free SPSC ring buffer antara thread decoder dan thread event pump `libusb`.

---

## Fitur Utama

- **Bit-Perfect USB DAC Output:** Melepas driver kernel `snd-usb-audio` dan mengirim PCM mentah sesuai sample rate & bit depth asli trek ke DAC eksternal (bypass total saat PEQ off dan volume `100%`).
- **64-Bit Parametric Equalizer (PEQ):** Editor kurva interaktif 10-band (`PeqEditorSheet`), dukungan preset JSON lokal, serta import profil `.txt` format AutoEq / Squiglink.
- **Master Digital Volume Attenuator:** Kontrol volume presisi (slider UI & tombol volume fisik perangkat) dengan bit-perfect bypass otomatis pada level `100%`.
- **Direct Filesystem & SD Card Scanner:** Pemindaian langsung penyimpanan internal dan Micro SD Card, filter folder sistem/sampah, *instant exclusion blacklist*, dan cache JSON atomik (`LibraryCacheService`) untuk *cold boot* cepat.
- **Antarmuka Lean 3+3 & Kontrol Taktil:**
  - `EvaSplashScreen` (animasi boot terminal & tap-to-skip)
  - `LibraryPage` (tab Tracks, Folders dengan `FolderTreeView`, Albums) & `CollectionDetailPage`
  - `NowPlayingPage` dengan rotary scrubber `DiscSeekWheel`
  - `PeqEditorSheet`, `QueueSheet` (drag-to-reorder), `SystemConsoleSheet` (diagnostik USB & software preview fallback), `AudioInspectorSheet`, dan `SleepTimerSheet`.

---

## Struktur Direktori Utama

```text
tannhauser_music_player/
├── lib/
│   ├── core/
│   │   ├── theme/          # Token warna, tipografi monospace, spasi, dan tema EVA-01
│   │   └── widgets/        # Komponen UI reusable (TrackTile, StatusPill, TactileButton, dll.)
│   ├── features/
│   │   ├── library/        # LibraryPage, CollectionDetailPage, FolderTreeView, Cache & Scanner HUD
│   │   ├── peq/            # PeqEditorSheet, PeqState, PeqGraphWidget
│   │   ├── player/         # NowPlayingPage, QueueSheet, DiscSeekWheel, SleepTimer, AudioInspector
│   │   ├── splash/         # EvaSplashScreen
│   │   └── system/         # SystemConsoleSheet
│   ├── services/           # NativeAudioService (Platform Channel bridge)
│   └── main.dart
└── android/app/src/main/
    ├── cpp/
    │   ├── CMakeLists.txt
    │   ├── engine/         # audio_engine, audio_decoder, usb_driver, peq_engine, ring_buffer
    │   ├── jni/            # jni_bridge.cpp
    │   ├── include/        # Header FFmpeg & libusb
    │   └── libs/arm64-v8a/ # Prebuilt .so (libusb1.0, libavcodec, libavformat, libavutil, libswresample)
    └── kotlin/com/example/tannhauser_music_player/
        ├── bridge/         # NativeAudioBridge.kt
        ├── scanner/        # FileScanner.kt
        ├── service/        # AudioPlaybackService.kt
        ├── usb/            # UsbBridge.kt
        └── MainActivity.kt
```

---

## Prasyarat & Menjalankan Proyek

### Prasyarat
- **Flutter SDK** (Dart SDK `^3.14.0`, sesuai `pubspec.yaml`)
- **Android NDK** (`26.3.11579264`, sesuai `android/app/build.gradle.kts`) dengan **CMake `3.22.1+`**
- **Target ABI:** `arm64-v8a`
- **Prebuilt Native Libraries** di `android/app/src/main/cpp/libs/arm64-v8a/`:
  - `libusb1.0.so`
  - `libavcodec.so`
  - `libavformat.so`
  - `libavutil.so`
  - `libswresample.so`
- Perangkat Android fisik (dengan dukungan USB OTG / USB Host) + USB Dongle DAC untuk pengujian output bit-perfect.

### Perintah Build & Run

```bash
# 1. Unduh dependensi Flutter
flutter pub get

# 2. Jalankan pada perangkat Android terhubung (arm64-v8a)
flutter run

# 3. Build APK release
flutter build apk --release
```

---

## Dokumentasi Terkait

Dokumentasi arsitektur, aturan kolaborasi, dan spesifikasi teknis lengkap tersedia di direktori [`../docs/`](../docs/):
- [`plan.md`](../docs/plan.md) — Rencana arsitektur & target perangkat
- [`rules.md`](../docs/rules.md) — Aturan arsitektur native & Zero Mixer Policy
- [`features.md`](../docs/features.md) — Roadmap fitur & guardrail teknis
- [`pages.md`](../docs/pages.md) — Spesifikasi navigasi & layar Lean 3+3
- [`ui_style.md`](../docs/ui_style.md) — Panduan visual EVA-01 Tactical Audio Terminal
- [`library_scanner_spec.md`](../docs/library_scanner_spec.md) — Spesifikasi Direct Filesystem Scanner & Cache
- [`peq_dsp_spec.md`](../docs/peq_dsp_spec.md) — Spesifikasi DSP Engine 64-bit PEQ
- [`progress.md`](../docs/progress.md) — Log progres pengerjaan
