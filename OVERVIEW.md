# Deploy and Host NarratoAI on Railway

NarratoAI is an open-source (MIT) web app that turns a video into a narrated commentary cut. A vision model looks at keyframes, a text model writes the narration script, a voice engine reads it aloud, and ffmpeg trims the clips and merges voice, subtitles and background music into a new video.

## About Hosting NarratoAI

NarratoAI is a Streamlit web UI that runs ffmpeg and calls an LLM API, so hosting it means a Python service with ffmpeg and ImageMagick, persistent storage for uploads, scripts and rendered videos, and a login, because Streamlit has none of its own. This template builds NarratoAI v0.8.7 from its tagged release, puts a Caddy proxy with a generated password in front, and keeps `config.toml`, `storage/` and `resource/` on a Railway volume at `/data`. On the first boot it writes your OpenAI-compatible key, base URL and model into NarratoAI's config, picks Edge TTS (free online voices) instead of a local voice model, and sizes ffmpeg threads to the service's CPUs.

## Common Use Cases

* Turn documentaries, nature or build videos into short narrated commentary clips for social media
* Write and voice a recap of a film or short-drama episode from its subtitles
* Draft a narration script with an LLM, edit it in the browser, then render the finished video

## Dependencies for NarratoAI Hosting

* An OpenAI-compatible LLM API key that can read images (OpenAI, OpenRouter, DeepSeek, SiliconFlow and others)
* One Railway service with a volume (included in this template)

### Deployment Dependencies

* NarratoAI source and docs: https://github.com/linyqh/NarratoAI
* Template repo (Dockerfile, start script, changelog): https://github.com/aalfath/narratoai-railway-template
* Get an OpenAI key: https://platform.openai.com/api-keys

### Implementation Details

**What you get:** one service, `NarratoAI`, with a public URL, a 401 login in front of the whole UI, an open `/healthz` for Railway's health check, and a volume at `/data`.

**After deploy:**

1. Open the service's **Variables** tab and copy `NARRATOAI_PASSWORD`. Log in at the public URL as `admin` with that password.
2. Upload a video in the script panel (up to 500 MB on a 0.5 GB service, 2 GB on larger ones), choose a mode, then generate the script and the video.
3. Rendered videos are saved under `storage/tasks` on the volume and can be downloaded from the UI.

**Variables:** `OPENAI_API_KEY` is the only prompt. `OPENAI_BASE_URL` (default `https://api.openai.com/v1`) and `OPENAI_MODEL` (default `gpt-4.1-mini`) point it at any OpenAI-compatible provider; the model must accept images. Values set here override the LLM fields in the UI on each restart; everything else you change in the UI is kept.

**Memory:** the app idles at about 110 MB. On a 0.5 GB / 1 vCPU service (Railway's Free plan) a 60-second 720p clip rendered to 1080p end to end, because the template caps ffmpeg threads to the service's CPUs and uses a smaller x264 lookahead below 1.5 GB. Long videos need 1–2 GB: raise the service's memory if a render stops.

**Left out:** local voice and speech models (IndexTTS, VoxCPM, OmniVoice, faster-whisper) need a GPU or several GB of RAM. Point their URLs at your own servers in the UI if you have them. Cloud voices (Azure, Tencent, Qwen) work with your own keys.

**Updates:** the service builds from the template repo. When we publish a new NarratoAI version, Railway shows an "update available" notice on your project; read the repo's `CHANGELOG.md` and apply it when you're ready. Your volume is kept.

## Why Deploy NarratoAI on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying NarratoAI on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
