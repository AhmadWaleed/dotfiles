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
CUDA has an unresolved upstream bug on this machine that crashes on
generation (cublasCreate_v2 resource allocation failure -
https://github.com/ggml-org/llama.cpp/issues/25304). Vulkan sidesteps it
entirely and still runs on the RTX 4070 via the proprietary driver.

`--models-max 1` keeps only one model loaded at a time - the RTX 4070 here
has 8GB VRAM, not enough to hold two large models concurrently. Switching
models reloads (a few seconds), it doesn't restart the server.

`llama-router` also hardcodes `-ncmoe 32`, a GPU/CPU offload split tuned
specifically for Qwen3.6-35B-A3B via `llama fit-params`. A different model
(different size or layer count) will want a different value - recompute it:

```
llama fit-params -hf <org>/<repo>-GGUF:<quant> -c 32768 -fa on -ctk q8_0 -ctv q8_0 \
  --fit-print on -ncmoe N
```

Try a few values of `N` and pick the largest offload (smallest `N`) whose
CUDA0/device total still leaves ~1GB headroom under your free VRAM.
