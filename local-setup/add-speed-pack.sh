#!/bin/bash
# Faster, lower-memory Qwen for 16 GB Macs: a Q2_K model (7.4 GB instead of 10 GB)
# and a GGUF text reader (4.7 GB + 1.4 GB instead of 9 GB). About 13.5 GB to download.
set -euo pipefail

COMFY="/Volumes/AIKIT/ComfyUI"
if [ ! -x "$COMFY/.venv/bin/python" ]; then
  echo "AIKIT isn't mounted. Double-click AIKit.sparsebundle first." >&2
  exit 1
fi
if pgrep -f "main.py --port 1234" >/dev/null; then
  echo "ComfyUI is running. Quit it first (Ctrl+C in its window, or Stop AI)." >&2
  exit 1
fi
UV="/Volumes/AIKIT/tools/uv"
export UV_CACHE_DIR="${TMPDIR:-/tmp}/aikit-uv-cache"
export UV_LINK_MODE=copy
REPO="https://github.com/ministryAI/Image-gen/raw/claude/github-qwen-image-gen-0wx25d/local-setup"

download() { # url dest
  if [ -s "$2" ]; then echo "    already have $(basename "$2")"; return; fi
  echo "    downloading $(basename "$2")"
  curl -L --fail --retry 5 -C - -o "$2.part" "$1"
  mv "$2.part" "$2"
}

echo "==> Updating the GGUF add-on"
rm -rf "$COMFY/custom_nodes/ComfyUI-GGUF"
curl -L https://github.com/city96/ComfyUI-GGUF/archive/refs/heads/main.tar.gz | tar xz -C "$COMFY/custom_nodes"
mv "$COMFY/custom_nodes/ComfyUI-GGUF-main" "$COMFY/custom_nodes/ComfyUI-GGUF"
"$UV" pip install --python "$COMFY/.venv/bin/python" -r "$COMFY/custom_nodes/ComfyUI-GGUF/requirements.txt"

echo "==> Downloading the smaller files onto AIKIT"
download "https://huggingface.co/Novice25/Qwen-Image-Edit-Rapid-AIO-GGUF/resolve/main/v23/Qwen-Rapid-NSFW-v23_Q2_K.gguf" \
  "$COMFY/models/unet/Qwen-Rapid-NSFW-v23_Q2_K.gguf"
TE="https://huggingface.co/unsloth/Qwen2.5-VL-7B-Instruct-GGUF/resolve/main"
download "$TE/Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf" "$COMFY/models/text_encoders/Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"
# The image-reading part; the GGUF loader finds it by this name next to the text reader.
download "$TE/mmproj-F16.gguf" "$COMFY/models/text_encoders/Qwen2.5-VL-7B-Instruct-mmproj-F16.gguf"

echo "==> Updating the simple page"
curl -L --fail -o "$COMFY/custom_nodes/aikit-simple-ui/web/index.html" "$REPO/simple-ui/web/index.html"

echo
echo "All set. Start AI again; the simple page picks the faster files automatically."
