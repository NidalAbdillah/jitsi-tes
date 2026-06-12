# ==========================================
# Case: Video Only (Windows)
# Bot join dengan kamera aktif, mic OFF
# ==========================================

import os, time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'))

JITSI_URL    = os.getenv("JITSI_URL", "https://jitsi-ccpdcs.infrasvc.id")
JITSI_ROOM   = os.getenv("JITSI_ROOM", "tes")
RUNTIME      = int(os.getenv("RUNTIME", 300))
NUM_SESSIONS = int(os.getenv("NUM_SESSIONS_VIDEO", 5))

DRIVER_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chromedriver.exe")

def start_session(username):
    opts = Options()
    opts.add_argument("--use-fake-device-for-media-stream")
    opts.add_argument("--use-fake-ui-for-media-stream")
    opts.add_argument("--disable-notifications")

    url = (
        f"{JITSI_URL}/{JITSI_ROOM}"
        f"#userInfo.displayName=%22{username}%22"
        f"&config.prejoinConfig.enabled=false"
        f"&config.startWithVideoMuted=false"
        f"&config.startWithAudioMuted=true"
        f"&config.p2p.enabled=false"
    )

    service = Service(DRIVER_PATH)
    driver = webdriver.Chrome(service=service, options=opts)
    driver.get(url)

    print(f"Loading {username}...")
    time.sleep(12)

    result = driver.execute_script('''
        return new Promise(resolve => {
            JitsiMeetJS.createLocalTracks({ devices: ["video"] })
            .then(tracks => {
                tracks.forEach(track => APP.conference.useVideoStream(track));
                resolve("ok: " + tracks.length + " track");
            })
            .catch(e => resolve("error: " + e));
        });
    ''')
    print(f"{username} tracks: {result}")
    time.sleep(3)
    print(f"{username} videoMuted={driver.execute_script('return APP.conference.isLocalVideoMuted();')} audioMuted={driver.execute_script('return APP.conference.isLocalAudioMuted();')}")
    return driver

sessions = []
for i in range(NUM_SESSIONS):
    sessions.append(start_session(f"Vid-{i+1:02d}"))

print(f"\nVerify: {JITSI_URL}/{JITSI_ROOM}")
print(f"Running {RUNTIME} seconds...")
time.sleep(RUNTIME)
for s in sessions: s.quit()
print("Done!")
