#!/bin/sh
# Run on the Linux deployment host from any directory. Never replaces models.
set -eu
umask 022

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
source_root="$repo_root/silvamang_ai_service/models"
target_root=${1:-/opt/silvamang/models}
case "$target_root" in
    /*) ;;
    *) echo 'The target must be an absolute server path.' >&2; exit 1 ;;
esac

model_files='EfficientNet-B0/efficientnet_b0_runtime.pth
EfficientNet-B0/class_order.json
YOLOv8-Detector/yolo8 detection.pt
YOLOv8-Seg/yolo8 seg.pt
MiDaS/midas_small_pretrained.pth'

# Check every source and destination before copying anything.
printf '%s\n' "$model_files" | while IFS= read -r relative; do
    source="$source_root/$relative"
    target="$target_root/$relative"
    test -s "$source" || { echo "Missing or empty source: $source" >&2; exit 1; }
    if [ -e "$target" ] || [ -L "$target" ]; then
        cmp -s "$source" "$target" || {
            echo "Existing model differs; refusing to overwrite: $target" >&2
            exit 1
        }
    fi
done

printf '%s\n' "$model_files" | while IFS= read -r relative; do
    source="$source_root/$relative"
    target="$target_root/$relative"
    if [ ! -e "$target" ]; then
        mkdir -p -- "$(dirname -- "$target")"
        cp -n -- "$source" "$target"
    fi
    cmp -s "$source" "$target" || { echo "Verification failed: $target" >&2; exit 1; }
    sha256sum -- "$target"
done

echo "Model bundle verified at $target_root"
echo 'Confirm container UID 10001 can read these files and traverse their parent directories, then redeploy in Dokploy.'
