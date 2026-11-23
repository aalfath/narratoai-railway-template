[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/narratoai?utm_medium=integration&utm_source=button&utm_campaign=narratoai)

# NarratoAI on Railway

One-click Railway template for [NarratoAI](https://github.com/linyqh/NarratoAI) **v0.8.7**
(MIT), a web app that turns a video into a narrated commentary cut: a vision LLM looks at
keyframes, a text LLM writes the narration, Edge TTS voices it, and ffmpeg cuts and merges
the result with subtitles.

## What it deploys

One service, **NarratoAI**, built from this repo's `Dockerfile`:

| Part | What it does |
| --- | --- |
| NarratoAI v0.8.7 (Streamlit, tag commit `022b8bb`) | The web UI and the video pipeline, on `127.0.0.1:8501` |
| Caddy 2.11.9 | Public port `$PORT` (8080): basic-auth login on everything, open `/healthz` for Railway's health check |
| ffmpeg 5.1 + ImageMagick (Debian bookworm) | Clipping, merging, subtitles |
| Volume at `/data` | `config.toml`, `storage/` (uploads, scripts, rendered videos) and `resource/` (fonts, music) |

Base images, pinned by version and digest:
`python:3.12.16-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df`
and `caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0`.
NarratoAI's release tarball and the Source Han Sans font are checked by SHA-256 at build time.
Python packages come from upstream's `uv.lock` (`uv sync --frozen`), plus `edge-tts` 7.3.1
because the locked 7.2.7 now gets HTTP 403 from Microsoft's voice service.

## Variables

| Variable | Default | Notes |
| --- | --- | --- |
| `OPENAI_API_KEY` | *(prompt)* | Your key for an OpenAI-compatible API. The model must read images. |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | Any OpenAI-compatible endpoint (OpenRouter, DeepSeek, SiliconFlow, a local gateway). |
| `OPENAI_MODEL` | `gpt-4.1-mini` | Used for both the vision and the narration step. `OPENAI_VISION_MODEL` overrides the vision one. |
| `NARRATOAI_USERNAME` | `admin` | Login user. |
| `NARRATOAI_PASSWORD` | generated, 24 characters | Login password; the app refuses to start with fewer than 12 characters. |
| `PORT` | `8080` | Caddy's port. |

The LLM variables are written into `config.toml` on every start; everything else you save in
the UI stays. Optional tuning: `NARRATOAI_THREADS`, `NARRATOAI_FFMPEG_THREADS`,
`NARRATOAI_X264_LOOKAHEAD`, `NARRATOAI_MAX_UPLOAD_MB`.

## Memory

Idle: about 110 MB. On a 0.5 GB / 1 vCPU service (Railway's Free plan) a 60-second 720p job
rendered to 1080p, end to end, because the start script caps ffmpeg threads to the service's
CPUs and, below 1.5 GB, uses a 10-frame libx264 lookahead (Railway shows 32 host CPUs inside
the container, and uncapped ffmpeg was OOM-killed). Uploads are capped at 500 MB below 1.5 GB
and 2 GB above it. For long videos give the service 1–2 GB.

## Left out

- Local voice and speech models (IndexTTS, VoxCPM, OmniVoice, faster-whisper): they need a
  GPU or several GB of RAM. Point their URLs at your own servers in the UI if you have them.
- GPU encoding: Railway has no GPUs; ffmpeg uses libx264.

## Updates

The service builds from this repo's `main` branch. When we bump NarratoAI or a base image,
Railway shows an "update available" notice on your project. Read [`CHANGELOG.md`](CHANGELOG.md)
(breaking changes first), then apply it. Your `/data` volume is kept.
