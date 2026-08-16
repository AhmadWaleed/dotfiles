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
llama serve --models-dir ~/models --models-max 1 -c 32768 -fa on --jinja --api-key local-dev-key
```

`--models-max 1` keeps only one model loaded at a time - the RTX 4070 here
has 8GB VRAM, not enough to hold two ~20GB+ models concurrently. Switching
models reloads (a few seconds), it doesn't restart the server.
