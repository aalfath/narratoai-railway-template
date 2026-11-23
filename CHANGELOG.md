# Changelog

Each entry lists breaking changes first. Railway shows deployers an "update available"
notice when `main` changes; read the entry before you apply it.

## v0.8.7-railway.1 (2026-11-23)

- First release: NarratoAI v0.8.7 (commit `022b8bb`), built from the tagged release on
  `python:3.12.16-slim-bookworm`, behind Caddy 2.11.9 with a generated login.
- Data (`config.toml`, `storage/`, `resource/`) lives on the Railway volume at `/data`.
- First boot seeds an OpenAI-compatible LLM from the service variables, Edge TTS voices,
  an English UI and video threads matched to the service's CPUs.
- `ffmpeg` runs through a small wrapper that caps its decoder, filter and encoder threads to
  the service's CPUs (`NARRATOAI_FFMPEG_THREADS` overrides it) and, below 1.5 GB of RAM, the
  libx264 lookahead to 10 frames (`NARRATOAI_X264_LOOKAHEAD`), so a 1080p render fits in 0.5 GB.
