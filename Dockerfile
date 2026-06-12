FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    chromium chromium-driver xvfb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN pip install --no-cache-dir selenium

COPY test_video.y4m .
COPY test_audio.wav .
COPY run_bot.py .

CMD ["bash", "-c", "Xvfb :99 -screen 0 1280x720x24 -ac & sleep 1 && DISPLAY=:99 python run_bot.py"]
