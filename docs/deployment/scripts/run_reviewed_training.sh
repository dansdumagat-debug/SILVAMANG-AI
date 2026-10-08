#!/bin/bash
# Runs on the VPS host; only the SILVAMANG training worker is resource-limited.
set -euo pipefail
exec 9>/run/lock/silvamang-reviewed-training.lock
flock -n 9 || exit 0
app=sivamangai-sivamangai-c0m98v-app-1
ai=sivamangai-sivamangai-c0m98v-ai-1
root=/opt/silvamang-reviewed-training
publish_status() {
  if [ -f "$root/status.json" ]; then
    docker cp "$root/status.json" "$app:/var/www/html/storage/app/retraining-status.json.pending" >/dev/null
    docker exec -u root "$app" sh -c 'chmod 644 /var/www/html/storage/app/retraining-status.json.pending && mv /var/www/html/storage/app/retraining-status.json.pending /var/www/html/storage/app/retraining-status.json'
  fi
}
available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
if [ "$available" -lt 2097152 ]; then
  printf '{"state":"waiting_for_resources","updated_at":"%s"}\n' "$(date -u +%FT%TZ)" > "$root/status.json"
  publish_status
  exit 0
fi
trap 'docker stop -t 30 silvamang-reviewed-training >/dev/null 2>&1 || true' TERM INT
docker exec -w /var/www/html "$app" php artisan dataset:training-snapshot
image=$(docker inspect --format '{{.Config.Image}}' "$ai")
docker run --rm --name silvamang-reviewed-training --init \
  --cpus=.75 --memory=1536m --memory-swap=1536m --pids-limit=128 \
  --network=none --read-only --cap-drop=ALL --security-opt=no-new-privileges \
  --tmpfs /tmp:rw,size=128m --user=0:0 \
  --volumes-from "$app:ro" --volumes-from "$ai:ro" \
  -v "$root:/training" -e OMP_NUM_THREADS=1 -e MKL_NUM_THREADS=1 \
  -e PYTHONDONTWRITEBYTECODE=1 --entrypoint python "$image" /training/worker.py &
pid=$!
while kill -0 "$pid" 2>/dev/null; do
  publish_status
  sleep 30
done
result=0
wait "$pid" || result=$?
if [ "$result" != 0 ]; then
  printf '{"state":"error","message":"Worker failed; inspect systemd logs","updated_at":"%s"}\n' "$(date -u +%FT%TZ)" > "$root/status.json"
fi
publish_status
exit "$result"
