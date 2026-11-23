"""Write NarratoAI's config.toml on the Railway volume.

First boot: start from upstream's config.example.toml and fill in the LLM settings
from the service variables, plus defaults that work on a CPU-only Railway service.
Later boots: only the LLM settings that come from variables are refreshed, so a
changed key or model in Railway's Variables tab wins; everything else the user
saved in the web UI stays as it is.
"""
import os, sys, toml

root = "/NarratoAI"
path = sys.argv[1]
env = os.environ

def first(*names, default=""):
    for n in names:
        v = env.get(n, "").strip()
        if v:
            return v
    return default

key = first("OPENAI_API_KEY")
base = first("OPENAI_BASE_URL", default="https://api.openai.com/v1")
text_model = first("OPENAI_MODEL", default="gpt-4.1-mini")
vision_model = first("OPENAI_VISION_MODEL", default=text_model)

fresh = not os.path.isfile(path)
if fresh:
    cfg = toml.load(f"{root}/config.example.toml")
else:
    cfg = toml.load(path)

app = cfg.setdefault("app", {})
llm = {
    "text_llm_provider": "openai",
    "text_openai_api_key": key,
    "text_openai_base_url": base,
    "text_openai_model_name": text_model,
    "vision_llm_provider": "openai",
    "vision_openai_api_key": key,
    "vision_openai_base_url": base,
    "vision_openai_model_name": vision_model,
}
# Variables only override when they are set, so a key saved in the web UI survives.
for k, v in llm.items():
    if v or fresh:
        app[k] = v

if fresh:
    for kind in ("text", "vision"):
        # Upstream's 65536 is rejected by most OpenAI models; 0 lets the API choose.
        app[f"{kind}_openai_max_tokens"] = 0
        app[f"{kind}_openai_temperature"] = 1.0
        app[f"{kind}_openai_top_p"] = 1.0
    app["n_threads"] = int(env.get("NARRATOAI_THREADS", "2"))
    app["hide_config"] = True
    ui = cfg.setdefault("ui", {})
    # IndexTTS (upstream's default) needs a separate GPU service; Edge TTS works out of the box.
    ui["tts_engine"] = "edge_tts"
    ui["edge_voice_name"] = "en-US-AvaMultilingualNeural-Female"
    ui["voice_name"] = "en-US-AvaMultilingualNeural-Female"
    ui["language"] = first("NARRATOAI_LANGUAGE", default="en")
    ui["font_name"] = "SourceHanSansCN-Regular.otf"
    frames = cfg.setdefault("frames", {})
    frames["vision_max_concurrency"] = 1

tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    f.write(toml.dumps(cfg))
os.replace(tmp, path)
print(f"narratoai-railway: {'created' if fresh else 'updated'} {path} (base URL {base}, text model {text_model}, vision model {vision_model}, key {'set' if key else 'NOT set'})")
