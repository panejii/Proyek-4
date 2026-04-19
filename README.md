# Logbook App 020

Aplikasi Logbook digital yang dirancang untuk mencatat aktivitas tim dengan dukungan mode offline-first. Aplikasi ini secara otomatis mensinkronisasikan data antara penyimpanan lokal (Hive) dan cloud (MongoDB Atlas).

## 🚀 Fitur Utama

- **Offline-First Capabilities**: Mencatat aktivitas kapan saja tanpa koneksi internet. Data disimpan di local storage menggunakan **Hive**.
- **Cloud Sync**: Sinkronisasi otomatis ke **MongoDB Atlas** saat perangkat kembali online.
- **Security Gatekeeper**: Sistem login dengan pembatasan percobaan akses untuk keamanan tambahan.
- **Vision & PCD Tools**: 
  - **AI Detection**: Fitur kamera real-time untuk deteksi objek atau kerusakan.
  - **PCD Operation**: Pengolahan Citra Digital untuk analisis gambar.
- **Role-Based Access**: Perbedaan hak akses antara 'Ketua' dan 'Anggota' dalam mengelola catatan.

## 🛠 Tech Stack

- **Framework**: Flutter
- **Database Utama**: MongoDB Atlas
- **Local Database**: Hive
- **Environment Management**: Flutter Dotenv
- **State Management**: ChangeNotify & ValueNotifier

## ⚙️ Cara Instalasi

### 1. Prasyarat
Pastikan Flutter SDK sudah terpasang di komputer kamu (Versi ^3.10.8).

### 2. Setup Environment
Buat file bernama `.env` di folder root proyek dan masukkan URI MongoDB kamu:
```env
MONGODB_URI=isi_dengan_uri_mongodb_atlas_kamu
