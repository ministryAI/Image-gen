#!/bin/bash
# Adds FLUX 3 Image Klein (int8 files + prompt upsampler) to the AIKIT drive,
# updating ComfyUI first so it knows the new model. Keeps your existing models.
set -euo pipefail

ROOT="/Volumes/AIKIT"
COMFY="$ROOT/ComfyUI"
[ -x "$COMFY/.venv/bin/python" ] || { echo "AIKIT isn't open or set up. Double-click AIKit.sparsebundle first." >&2; exit 1; }
if curl -fs -o /dev/null http://127.0.0.1:1234/; then
  echo "ComfyUI is running. Double-click 'Stop AI' (or Ctrl+C in its window), then run this again." >&2; exit 1
fi
UV="$ROOT/tools/uv"
export UV_CACHE_DIR="${TMPDIR:-/tmp}/aikit-uv-cache" UV_LINK_MODE=copy
TMP="${TMPDIR:-/tmp}/aikit-update"; rm -rf "$TMP"; mkdir -p "$TMP"
HF="https://huggingface.co/ml-resources/flux-3-image-klein-comfy/resolve/main"

download() { # url dest
  if [ -s "$2" ]; then echo "    already have $(basename "$2")"; return; fi
  echo "    downloading $(basename "$2")"
  curl -L --fail --retry 5 -C - -o "$2.part" "$1" && mv "$2.part" "$2"
}

echo "==> Updating ComfyUI (your models, pictures, add-ons and settings are kept)"
curl -L https://github.com/comfyanonymous/ComfyUI/archive/refs/heads/master.tar.gz | tar xz -C "$TMP"
rsync -a --exclude '.venv' --exclude 'models' --exclude 'custom_nodes' --exclude 'user' \
  --exclude 'input' --exclude 'output' --exclude 'requirements-mac.txt' "$TMP/ComfyUI-master/" "$COMFY/"
cd "$COMFY"
if ! "$UV" pip install --python .venv/bin/python -r requirements.txt; then
  grep -v -i "comfy-angle" requirements.txt > requirements-mac.txt
  "$UV" pip install --python .venv/bin/python -r requirements-mac.txt
fi
"$UV" pip install --python .venv/bin/python --upgrade torch torchvision torchaudio
rm -rf "$TMP" "$UV_CACHE_DIR"

echo "==> Downloading FLUX 3 Image Klein onto AIKIT (about 21 GB; this takes a while)"
mkdir -p models/diffusion_models models/text_encoders models/vae user/default/workflows
download "$HF/diffusion_models/flux3-image-klein-int8-convrot.safetensors" models/diffusion_models/flux3-image-klein-int8-convrot.safetensors
download "$HF/text_encoders/qwen3vl_4b_int8_convrot.safetensors" models/text_encoders/qwen3vl_4b_int8_convrot.safetensors
download "$HF/vae/flux2-vae.safetensors" models/vae/flux2-vae.safetensors
download "$HF/text_encoders/qwen3.5_9b_flux3_prompt_upsampler_int8_convrot.safetensors" models/text_encoders/qwen3.5_9b_flux3_prompt_upsampler_int8_convrot.safetensors

echo "==> Adding the official FLUX 3 Klein workflows"
for w in t2i i2i mi2i; do
  curl -fsSL "$HF/workflows/flux3_klein_int8_$w.json" -o "user/default/workflows/FLUX3 Klein - $w.json"
done

echo
echo "All set. Start AI, open the full editor (http://127.0.0.1:1234), Workflows > 'FLUX3 Klein - i2i'."
