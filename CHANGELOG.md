# Changelog

Each entry lists breaking changes first. Railway shows deployers an "update available"
notice when `main` changes; read the entry before you apply it.

## v0.8.7-railway.1 (2026-11-23)

- First release: NarratoAI v0.8.7 (commit `022b8bb`), built from the tagged release on
  `python:3.12.16-slim-bookworm`, behind Caddy 2.11.9 with a generated login.
- Data (`config.toml`, `storage/`, `resource/`) lives on the Railway volume at `/data`.
- First boot seeds an OpenAI-compatible LLM from the service variables, Edge TTS voices,
  an English UI and video threads matched to the service's CPUs.
