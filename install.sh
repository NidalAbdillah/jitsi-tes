#!/bin/bash
# ==========================================
# Jitsi Stress Test - Auto Installer
# ==========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "=========================================="
echo "  Jitsi Stress Test Installer"
echo "=========================================="
echo ""

# ------------------------------------------
# 1. Cek root
# ------------------------------------------
if [ "$EUID" -ne 0 ]; then
    error "Jalankan sebagai root: sudo bash install.sh"
fi
log "Running as root"

# ------------------------------------------
# 2. Update apt
# ------------------------------------------
log "Updating apt..."
apt-get update -qq

# ------------------------------------------
# 3. Install Xvfb & dependencies
# ------------------------------------------
log "Installing Xvfb..."
apt-get install -y xvfb x11-utils wget unzip curl > /dev/null 2>&1
log "Xvfb installed"

# ------------------------------------------
# 4. Install Google Chrome (non-snap)
# ------------------------------------------
if command -v google-chrome &> /dev/null; then
    log "Google Chrome already installed: $(google-chrome --version)"
else
    log "Installing Google Chrome..."
    CHROME_DEB="$SCRIPT_DIR/google-chrome-stable_current_amd64.deb"
    if [ ! -f "$CHROME_DEB" ]; then
        warn "Downloading Google Chrome..."
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O "$CHROME_DEB"
    fi
    dpkg -i "$CHROME_DEB" > /dev/null 2>&1 || apt-get install -f -y > /dev/null 2>&1
    log "Google Chrome installed: $(google-chrome --version)"
fi

# ------------------------------------------
# 5. Install ChromeDriver sesuai versi Chrome
# ------------------------------------------
CHROME_VER=$(google-chrome --version | grep -oP '\d+\.\d+\.\d+\.\d+')
CHROME_MAJOR=$(echo $CHROME_VER | cut -d. -f1)

if command -v chromedriver &> /dev/null; then
    DRIVER_VER=$(chromedriver --version | grep -oP '\d+' | head -1)
    if [ "$DRIVER_VER" = "$CHROME_MAJOR" ]; then
        log "ChromeDriver already installed: $(chromedriver --version | head -1)"
    else
        warn "ChromeDriver version mismatch, reinstalling..."
        rm -f /usr/local/bin/chromedriver
    fi
fi

if ! command -v chromedriver &> /dev/null; then
    log "Installing ChromeDriver $CHROME_VER..."
    DRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VER}/linux64/chromedriver-linux64.zip"
    wget -q "$DRIVER_URL" -O /tmp/chromedriver.zip
    unzip -q /tmp/chromedriver.zip -d /tmp/
    mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver
    chmod +x /usr/local/bin/chromedriver
    rm -rf /tmp/chromedriver.zip /tmp/chromedriver-linux64
    log "ChromeDriver installed: $(chromedriver --version | head -1)"
fi

# ------------------------------------------
# 6. Install Python3 & pip
# ------------------------------------------
log "Installing Python3 & pip..."
apt-get install -y python3 python3-pip > /dev/null 2>&1
log "Python: $(python3 --version)"

# ------------------------------------------
# 7. Install Python packages
# ------------------------------------------
log "Installing Python packages..."
pip3 install selenium python-dotenv --break-system-packages --ignore-installed -q
log "Selenium & python-dotenv installed"

# ------------------------------------------
# 8. Buat .env jika belum ada
# ------------------------------------------
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    log "Creating .env file..."
    cat > "$SCRIPT_DIR/.env" << 'ENVEOF'
# ==========================================
# Jitsi Stress Test - Environment Config
# ==========================================

# Base URL Jitsi server
JITSI_URL=https://jitsi-ccpdcs.infrasvc.id

# Nama room
JITSI_ROOM=tes

# Durasi test dalam detik
RUNTIME=300

# ------------------------------------------
# Jumlah bot per test case
# ------------------------------------------

# 📹🎤 Audio + Video (paling berat)
NUM_SESSIONS_AV=25

# 📹 Video only
NUM_SESSIONS_VIDEO=25

# 🎤 Audio only
NUM_SESSIONS_AUDIO=25

# 🔇 Silent / cam+mic off (paling ringan)
NUM_SESSIONS_SILENT=25
ENVEOF
    log ".env created"
else
    warn ".env already exists, skipping"
fi

# ------------------------------------------
# 9. Setup Xvfb sebagai systemd service
# ------------------------------------------
log "Setting up Xvfb service..."
cat > /etc/systemd/system/xvfb.service << 'SVCEOF'
[Unit]
Description=Xvfb Virtual Display
After=network.target

[Service]
ExecStart=/usr/bin/Xvfb :99 -screen 0 1280x720x24 -ac
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable xvfb > /dev/null 2>&1
systemctl restart xvfb
sleep 2
log "Xvfb service enabled & started"

# ------------------------------------------
# 10. Setup alias di /etc/profile.d
#     (auto load semua session, tanpa source)
# ------------------------------------------
log "Setting up aliases..."
cat > /etc/profile.d/jitsi-stress.sh << ALIASEOF
alias jitsi-av="DISPLAY=:99 python3 $SCRIPT_DIR/run_bot_audio_video.py"
alias jitsi-video="DISPLAY=:99 python3 $SCRIPT_DIR/run_bot_video_only.py"
alias jitsi-audio="DISPLAY=:99 python3 $SCRIPT_DIR/run_bot_audio_only.py"
alias jitsi-silent="DISPLAY=:99 python3 $SCRIPT_DIR/run_bot_cam_off.py"
ALIASEOF
chmod +x /etc/profile.d/jitsi-stress.sh

# Load langsung ke session ini juga
source /etc/profile.d/jitsi-stress.sh
log "Aliases configured & loaded"

# ------------------------------------------
# 11. Verifikasi semua komponen
# ------------------------------------------
echo ""
echo "=========================================="
echo "  Verifikasi Instalasi"
echo "=========================================="
echo ""

check() {
    if eval "$2" &> /dev/null; then
        log "$1: OK"
    else
        warn "$1: GAGAL - $3"
    fi
}

check "Google Chrome"          "google-chrome --version"                        "install chrome dulu"
check "ChromeDriver"           "chromedriver --version"                         "install chromedriver dulu"
check "Python3"                "python3 --version"                              "install python3 dulu"
check "Selenium"               "python3 -c 'import selenium'"                   "pip3 install selenium"
check "python-dotenv"          "python3 -c 'import dotenv'"                     "pip3 install python-dotenv"
check "Xvfb service"           "systemctl is-active xvfb"                       "systemctl restart xvfb"
check ".env file"              "test -f $SCRIPT_DIR/.env"                       "buat .env dulu"
check "run_bot_audio_video"    "test -f $SCRIPT_DIR/run_bot_audio_video.py"     "file tidak ada"
check "run_bot_video_only"     "test -f $SCRIPT_DIR/run_bot_video_only.py"      "file tidak ada"
check "run_bot_audio_only"     "test -f $SCRIPT_DIR/run_bot_audio_only.py"      "file tidak ada"
check "run_bot_cam_off"        "test -f $SCRIPT_DIR/run_bot_cam_off.py"         "file tidak ada"
check "alias jitsi-av"         "type jitsi-av"                                  "source /etc/profile.d/jitsi-stress.sh"

echo ""
echo "=========================================="
echo "  Instalasi Selesai!"
echo "=========================================="
echo ""
echo "  Langsung jalankan:"
echo ""
echo "  jitsi-av      → 📹🎤 Cam + Mic ON"
echo "  jitsi-video   → 📹  Cam ON, Mic OFF"
echo "  jitsi-audio   → 🎤  Mic ON, Cam OFF"
echo "  jitsi-silent  → 🔇  Cam + Mic OFF"
echo ""
echo "  Edit konfigurasi: nano $SCRIPT_DIR/.env"
echo ""

# Load alias ke session aktif sekarang
exec bash --rcfile /etc/profile.d/jitsi-stress.sh
