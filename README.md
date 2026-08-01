# kotoshu Docker CI image

Pre-warmed Kotoshu image for CI runners. `docker run` gives you a working
`kotoshu check` with English dictionary already cached — no per-run
download.

## Use in CI

```yaml
# GitHub Actions example (use action-kotoshu for the action wrapper)
- uses: docker://ghcr.io/kotoshu/ci:latest
  with:
    args: kotoshu check README.md --format sarif
```

## Local

```bash
docker build -t kotoshu-ci .
docker run --rm -v "$PWD:/work" -w /work kotoshu-ci \
  kotoshu check README.md --format json
```

To add another language at build time, pass `KOTOSHU_PREWARM_LANGS`:

```bash
docker build -t kotoshu-ci \
  --build-arg KOTOSHU_PREWARM_LANGS="en de fr" .
```

## Image layout

| Path | Contents |
|---|---|
| `/usr/local/bundle` | kotoshu gem + runtime deps |
| `/root/.cache/kotoshu/` | pre-warmed dictionaries (read-only in CI mode) |
| `/work` | default `WORKDIR`; mount your repo here |

## Env vars

| Env | Default | Notes |
|---|---|---|
| `KOTOSHU_OFFLINE` | `1` | Pre-set so the CI image never hits the network unexpectedly |
| `XDG_CACHE_HOME` | `/root/.cache` | Where kotoshu looks for caches |

Override `KOTOSHU_OFFLINE=0` if you want the CI image to download a new
language at runtime.
