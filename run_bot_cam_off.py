# ==========================================
# 🔇 Case: Silent / Cam + Mic OFF
# Bot join tanpa kamera dan mikrofon
# Kondisi paling ringan, test koneksi saja
# ==========================================

import os, time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))

JITSI_URL        = os.getenv("JITSI_URL", "https://jitsi-ccpdcs.infrasvc.id")
JITSI_ROOM       = os.getenv("JITSI_ROOM", "tes")
RUNTIME          = int(os.getenv("RUNTIME", 300))
NUM_SESSIONS     = int(os.getenv("NUM_SESSIONS_SILENT", 25))

def start_session(username):
    opts = Options()
    opts.binary_location = "/usr/bin/google-chrome"
    opts.add_argument("--use-fake-device-for-media-stream")
    opts.add_argument("--use-fake-ui-for-media-stream")
    opts.add_argument("--disable-notifications")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")

    url = (
        f"{JITSI_URL}/{JITSI_ROOM}"
        f"#userInfo.displayName=%22{username}%22"
        f"&config.prejoinConfig.enabled=false"
        f"&config.startWithVideoMuted=true"
        f"&config.startWithAudioMuted=true"
        f"&config.p2p.enabled=false"
    )

    service = Service("/usr/local/bin/chromedriver")
    driver = webdriver.Chrome(service=service, options=opts)
    driver.get(url)

    print(f"⏳ {username} loading...")
    time.sleep(12)

    print(f"✅ {username} videoMuted={driver.execute_script('return APP.conference.isLocalVideoMuted();')} audioMuted={driver.execute_script('return APP.conference.isLocalAudioMuted();')}")
    return driver

sessions = []
for i in range(NUM_SESSIONS):
    sessions.append(start_session(f"Silent-{i+1:02d}"))

print(f"\nVerify: {JITSI_URL}/{JITSI_ROOM}")
print(f"Running {RUNTIME} seconds...")
time.sleep(RUNTIME)
for s in sessions: s.quit()
print("Done!")
