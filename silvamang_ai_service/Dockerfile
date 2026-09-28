FROM python:3.12-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 \
    APP_ENV=production APP_DEBUG=false TORCH_HOME=/home/ai/.cache/torch \
    YOLO_CONFIG_DIR=/home/ai/.cache/ultralytics
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 ai
COPY requirements-production.txt ./
RUN pip install --no-cache-dir torch==2.13.0 torchvision==0.28.0 --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir -r requirements-production.txt \
    && pip check
COPY app ./app
COPY docker ./docker
# Supply weights separately as a read-only host mount.
RUN mkdir -p /app/models /home/ai/.cache/torch /home/ai/.cache/ultralytics \
    && chown -R ai:ai /home/ai/.cache
USER ai
EXPOSE 9000
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:9000/livez', timeout=3)"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "9000", "--workers", "1", "--no-proxy-headers", "--timeout-keep-alive", "5"]
