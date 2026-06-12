# Jitsi Stress Test - Windows

## Persiapan
1. Install Python 3 dari https://www.python.org/downloads/ (centang "Add Python to PATH")
2. Install Google Chrome (kalau belum ada)
3. Buka folder ini, install dependency:
   pip install -r requirements.txt
4. Download ChromeDriver versi SAMA dengan Chrome kamu:
   - Cek versi: chrome://settings/help
   - Download: https://googlechromelabs.github.io/chrome-for-testing/
   - Letakkan chromedriver.exe (win64) di folder ini

## Konfigurasi (.env)
- JITSI_URL, JITSI_ROOM, RUNTIME, NUM_SESSIONS_*

## Cara Jalan
Double click:
- jitsi-av.bat     -> Cam ON + Mic ON
- jitsi-video.bat  -> Cam ON, Mic OFF
- jitsi-audio.bat  -> Mic ON, Cam OFF
- jitsi-silent.bat -> Cam OFF, Mic OFF
