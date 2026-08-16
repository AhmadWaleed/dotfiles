# ~/models

GGUF files (symlinks into `~/.cache/huggingface/hub/`, or downloaded here
directly) for the local `llama.cpp` router server. Contents are gitignored -
models are large, binary, and machine-specific, not configuration.

Add a model:

```
llama download -hf <org>/<repo>-GGUF:<quant>
ln -sf ~/.cache/huggingface/hub/models--<org>--<repo>-GGUF/snapshots/*/*.gguf \
  ~/models/<name>.gguf
```

Serve everything here, switchable at runtime (via OpenCode's `/models`, or
the web UI dropdown at `http://127.0.0.1:8080`):

```
llama-router
```

That's `~/.local/bin/llama-router` - see it for the full flag breakdown and
reasoning. Notably it uses the Vulkan build (`llama-server-vk`, downloaded
from llama.cpp's GitHub releases), not the `llama` CLI's own CUDA backend:
as of writing, CUDA has an unresolved upstream bug that crashes on
generation for large models (cublasCreate_v2 resource allocation failure -
https://github.com/ggml-org/llama.cpp/issues/25304). Vulkan sidesteps it
entirely, at some performance cost vs. a working CUDA setup - worth
retrying `llama serve` (CUDA) if that issue is closed by the time you read
this.

`--models-max 1` keeps only one model loaded at a time - fine for a single
consumer GPU, which typically doesn't have enough VRAM to hold multiple
large models concurrently. Switching models reloads (a few seconds), it
doesn't restart the server.

**First-time setup on a new machine:** `llama-router` needs a few
hardware-specific numbers it can't guess safely - which GPU to use (if you
have more than one), how many MoE expert layers to keep on CPU vs. GPU, and
CPU thread count. These go in `~/.config/llama-router/env`, *not* tracked
in this repo (same reasoning as `.claude/settings.local.json` - see the
root README's "Not tracked here" section). Without it, `llama-router` falls
back to generic defaults (auto device selection, no forced CPU offload, all
CPU cores) - safe on a small/fully-GPU-resident model, but auto-fit for GPU
layer placement has known bugs with large MoE models (same issue as above),
so compute your own values instead of trusting auto for anything big:

```
llama-server-vk --list-devices                    # find your GPU's name/index

llama fit-params -hf <org>/<repo>-GGUF:<quant> -c 32768 -fa on -ctk q8_0 -ctv q8_0 \
  --fit-print on -ncmoe N
```

Try a few values of `N` and pick the largest offload (smallest `N`) whose
device total still leaves ~1GB headroom under your free VRAM. Physical
(not logical/hyperthread) CPU core count is usually the right thread count.
Then:

```
mkdir -p ~/.config/llama-router
cat > ~/.config/llama-router/env << 'EOF'
LLAMA_DEVICE=<from --list-devices>
LLAMA_NCMOE=<tuned N>
LLAMA_THREADS=<physical core count>
EOF
```
