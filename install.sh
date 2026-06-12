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
INSTALL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$INSTALL_USER")

echo ""
echo "=========================================="
echo "  Jitsi Stress Test Installer"
echo "  Script dir : $SCRIPT_DIR"
echo "  User       : $INSTALL_USER"
echo "  Home       : $USER_HOME"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    error "Jalankan sebagai root: sudo bash install.sh"
fi
log "Running as root"

log "Updating apt..."
apt-get update -qq

log "Installing Xvfb..."
apt-get install -y xvfb x11-utils > /dev/null 2>&1
log "Xvfb installed"

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

if command -v chromedriver &> /dev/null; then
    log "ChromeDriver already installed: $(chromedriver --version | head -1)"
else
    log "Installing ChromeDriver..."
    apt-get install -y chromium-driver > /dev/null 2>&1 || true
    if ! command -v chromedriver &> /dev/null; then
        CHROME_VER=$(google-chrome --version | grep -oP '\d+\.\d+\.\d+\.\d+')
        warn "Downloading ChromeDriver for Chrome $CHROME_VER..."
        DRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VER}/linux64/chromedriver-linux64.zip"
        wget -q "$DRIVER_URL" -O /tmp/chromedriver.zip
        unzip -q /tmp/chromedriver.zip -d /tmp/
        mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver
        chmod +x /usr/local/bin/chromedriver
        rm -rf /tmp/chromedriver.zip /tmp/chromedriver-linux64
    fi
    log "ChromeDriver installed: $(chromedriver --version | head -1)"
fi

log "Installing Python3 & pip..."
apt-get install -y python3 python3-pip > /dev/null 2>&1
log "Python: $(python3 --version)"

log "Installing Python packages..."
pip3 install selenium python-dotenv --break-system-packages --ignore-installed -q
log "Selenium & python-dotenv installed"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    log "Creating .env file..."
    cat > "$SCRIPT_DIR/.env" << ENVEOF
# ==========================================
# Jitsi Stress Test - Environment Config
# ==========================================

JITSI_URL=https://jitsi-ccpdcs.infrasvc.id
JITSI_ROOM=tes
RUNTIME=300

NUM_SESSIONS_AV=25
NUM_SESSIONS_VIDEO=25
NUM_SESSIONS_AUDIO=25
NUM_SESSIONS_SILENT=25
ENVEOF
    log ".env created at $SCRIPT_DIR/.env"
else
    warn ".env already exists, skipping"
fi

log "Setting up Xvfb service..."
cat > /etc/systemd/system/xvfb.service << SVCEOF
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
log "Xvfb service enabled & started"

log "Setting up aliases..."
cat > /etc/profile.d/jitsi-stress.sh << ALIASEOF
alias jitsi-av="DISPLAY=:99 python3 $SCRIPT_DIR/run_bot_audio_video.py"
alias jitsi-video="DISPLAY=:99 python3 $SCRIPT_DIR/run_bot_video_only.py"
alias jitsi-audio="DISPLAY=:99 python3 $SCRIPT_DIR/run_bot_audio_only.py"
alias jitsi-silent="DISPLAY=:99 python3 $SCRIPT_DIR/run_bot_cam_off.py"
ALIASEOF
chmod +x /etc/profile.d/jitsi-stress.sh
source /etc/profile.d/jitsi-stress.sh
log "Aliases configured"

echo ""
echo "=========================================="
echo "  Verifikasi Instalasi"
echo "=========================================="
check() { if eval "$2" &> /dev/null; then log "$1: OK"; else warn "$1: GAGAL"; fi; }
check "Google Chrome"       "google-chrome --version"
check "ChromeDriver"        "chromedriver --version"
check "Python3"             "python3 --version"
check "Selenium"            "python3 -c 'import selenium'"
check "python-dotenv"       "python3 -c 'import dotenv'"
check "Xvfb service"        "systemctl is-active xvfb"
check ".env file"           "test -f $SCRIPT_DIR/.env"
check "run_bot_audio_video" "test -f $SCRIPT_DIR/run_bot_audio_video.py"
check "run_bot_video_only"  "test -f $SCRIPT_DIR/run_bot_video_only.py"
check "run_bot_audio_only"  "test -f $SCRIPT_DIR/run_bot_audio_only.py"
check "run_bot_cam_off"     "test -f $SCRIPT_DIR/run_bot_cam_off.py"

echo ""
echo "=========================================="
echo "  Instalasi Selesai!"
echo "=========================================="
echo "  Config : $SCRIPT_DIR/.env"
echo ""
echo "  jitsi-av      → Cam + Mic ON"
echo "  jitsi-video   → Cam ON, Mic OFF"
echo "  jitsi-audio   → Mic ON, Cam OFF"
echo "  jitsi-silent  → Cam + Mic OFF"
echo ""
