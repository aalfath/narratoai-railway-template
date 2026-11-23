# NarratoAI for Railway: NarratoAI built from its pinned release, with a small Caddy
# front that adds a login (HTTP basic auth) and an open /healthz for Railway.
# Upstream publishes no Docker image, so we build the tagged release commit.
# Bump the pins below together with a CHANGELOG.md entry; a merge to main notifies deployers.
ARG NARRATOAI_VERSION=v0.8.7
ARG NARRATOAI_COMMIT=022b8bbea3d48f0f60201dd27635ab78ea6ad86a
ARG NARRATOAI_SHA256=3ce5ce20539777489eb9f74d25e2398aa0acaa29c54b657dfbaff08556b816e8

FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

# ---- source: the release tarball, checked against its sha256 ----
FROM python:3.12.16-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df AS source
ARG NARRATOAI_COMMIT
ARG NARRATOAI_SHA256
# Source Han Sans SC (SIL OFL 1.1) for subtitles, pinned to Adobe's 2.005R tag.
ARG FONT_URL=https://raw.githubusercontent.com/adobe-fonts/source-han-sans/2.005R/OTF/SimplifiedChinese/SourceHanSansSC-Regular.otf
ARG FONT_SHA256=f1d8611151880c6c336aabeac4640ef434fa13cbfbf1ffe82d0a71b2a5637256
COPY fetch.py /tmp/fetch.py
RUN NARRATOAI_COMMIT="${NARRATOAI_COMMIT}" NARRATOAI_SHA256="${NARRATOAI_SHA256}" FONT_URL="${FONT_URL}" FONT_SHA256="${FONT_SHA256}" python /tmp/fetch.py

# ---- builder: Python dependencies from upstream's uv.lock ----
FROM python:3.12.16-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df AS builder
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir uv==0.13.9
ENV UV_PROJECT_ENVIRONMENT=/opt/venv UV_LINK_MODE=copy UV_COMPILE_BYTECODE=1 UV_CONCURRENT_DOWNLOADS=4 UV_CONCURRENT_BUILDS=2
WORKDIR /build
COPY --from=source /src/pyproject.toml /src/uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project && rm -rf /root/.cache

# ---- runtime ----
FROM python:3.12.16-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df
ARG NARRATOAI_VERSION
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg imagemagick ca-certificates \
    && sed -i 's/<policy domain="path" rights="none" pattern="@\*"/<policy domain="path" rights="read|write" pattern="@\*"/' /etc/ImageMagick-6/policy.xml \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r -g 1000 narratoai && useradd -r -u 1000 -g narratoai -d /NarratoAI -s /usr/sbin/nologin narratoai

COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=builder /opt/venv /opt/venv
COPY --from=source /src /NarratoAI
COPY --from=source /tmp/SourceHanSansCN-Regular.otf /opt/narratoai-railway/fonts/SourceHanSansCN-Regular.otf
COPY Caddyfile seed_config.py /opt/narratoai-railway/
COPY start.sh /usr/local/bin/narratoai-railway-start

# The image keeps a pristine copy of resource/ to seed the volume; storage/, resource/
# and config.toml become links into /data (the Railway volume) at start.
# Video threads default to the service's CPUs instead of upstream's 16.
RUN cd /NarratoAI \
    && sed -i 's/n_threads: Optional\[int\] = Field(default=16,/n_threads: Optional[int] = Field(default_factory=lambda: int(__import__("os").environ.get("NARRATOAI_THREADS", "2")),/' app/models/schema.py \
    && grep -q 'NARRATOAI_THREADS' app/models/schema.py \
    && mv resource /opt/narratoai-railway/resource \
    && rm -rf storage docker-entrypoint.sh docker-deploy.sh tests \
    && echo "${NARRATOAI_VERSION}" > /opt/narratoai-railway/VERSION \
    && chmod 0755 /usr/local/bin/narratoai-railway-start \
    && chown -R narratoai:narratoai /NarratoAI

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH=/NarratoAI \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONIOENCODING=utf-8 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MALLOC_ARENA_MAX=2 \
    STREAMLIT_BROWSER_GATHER_USAGE_STATS=false \
    NARRATOAI_DATA_DIR=/data \
    PORT=8080

EXPOSE 8080
# Starts as root only to fix the volume's ownership, then runs NarratoAI and Caddy
# as the unprivileged "narratoai" user.
ENTRYPOINT ["/usr/local/bin/narratoai-railway-start"]
