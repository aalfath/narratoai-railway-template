#!/bin/sh
# Start NarratoAI (Streamlit on 127.0.0.1:8501) and Caddy ($PORT: login + /healthz).
# Exits non-zero as soon as either process stops, so Railway restarts the service.
set -eu

DATA="${NARRATOAI_DATA_DIR:-/data}"
APP=/NarratoAI
export NARRATOAI_USERNAME="${NARRATOAI_USERNAME:-admin}"

if [ -z "${NARRATOAI_PASSWORD:-}" ] || [ "${#NARRATOAI_PASSWORD}" -lt 12 ]; then
	echo "narratoai-railway: NARRATOAI_PASSWORD must be set (12+ characters). Refusing to start an open server." >&2
	exit 1
fi

# CPUs and memory from the container's cgroup, not the host's (Railway shows 32 CPUs).
cpus=2
if [ -r /sys/fs/cgroup/cpu.max ]; then
	set -- $(cat /sys/fs/cgroup/cpu.max)
	if [ "$1" != "max" ]; then cpus=$(( ($1 + $2 - 1) / $2 )); fi
fi
[ "$cpus" -lt 1 ] && cpus=1
[ "$cpus" -gt 8 ] && cpus=8
limit_mb=0
if [ -r /sys/fs/cgroup/memory.max ]; then
	raw=$(cat /sys/fs/cgroup/memory.max)
	[ "$raw" != "max" ] && limit_mb=$((raw / 1048576))
fi
export NARRATOAI_THREADS="${NARRATOAI_THREADS:-$cpus}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$cpus}" OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-$cpus}" MKL_NUM_THREADS="${MKL_NUM_THREADS:-$cpus}"
export MAGICK_THREAD_LIMIT="${MAGICK_THREAD_LIMIT:-$cpus}" GOMAXPROCS="${GOMAXPROCS:-$cpus}"
# libx264's default 40-frame lookahead holds ~450 MB at 1080p even on one thread; below
# 1.5 GB use a 10-frame lookahead (~240 MB, same speed and size within 2 %).
if [ -z "${NARRATOAI_X264_LOOKAHEAD:-}" ] && [ "$limit_mb" -gt 0 ] && [ "$limit_mb" -lt 1500 ]; then
	export NARRATOAI_X264_LOOKAHEAD=10
fi
# Upload cap: 2 GB upstream; smaller services get a smaller cap so one upload can't fill memory.
if [ -z "${NARRATOAI_MAX_UPLOAD_MB:-}" ]; then
	NARRATOAI_MAX_UPLOAD_MB=2048
	if [ "$limit_mb" -gt 0 ] && [ "$limit_mb" -lt 1500 ]; then NARRATOAI_MAX_UPLOAD_MB=500; fi
fi

# The volume holds config.toml, storage/ (tasks, scripts, outputs) and resource/ (videos, songs, fonts).
mkdir -p "$DATA/storage" "$DATA/resource"
for d in temp tasks json narration_scripts drama_analysis; do mkdir -p "$DATA/storage/$d"; done
# Seed resource/ from the image without overwriting anything the user added.
cp -rn /opt/narratoai-railway/resource/. "$DATA/resource/"
mkdir -p "$DATA/resource/fonts"
[ -s "$DATA/resource/fonts/SourceHanSansCN-Regular.otf" ] || cp /opt/narratoai-railway/fonts/SourceHanSansCN-Regular.otf "$DATA/resource/fonts/"
python /opt/narratoai-railway/seed_config.py "$DATA/config.toml"
for p in storage resource config.toml; do
	rm -rf "${APP:?}/$p"
	ln -s "$DATA/$p" "$APP/$p"
done
if [ "$(stat -c %u "$DATA")" != 1000 ] || [ "$(stat -c %u "$DATA/config.toml")" != 1000 ]; then
	chown -R narratoai:narratoai "$DATA"
fi
# Clear half-written temp files left by a previous crash.
find "$DATA/storage/temp" -mindepth 1 -mmin +60 -delete 2>/dev/null || true

NARRATOAI_PASSWORD_HASH=$(caddy hash-password --algorithm bcrypt --bcrypt-cost 10 --plaintext "$NARRATOAI_PASSWORD")
mkdir -p /tmp/caddy && chown narratoai:narratoai /tmp/caddy
export HOME=/tmp/caddy XDG_CONFIG_HOME=/tmp/caddy XDG_DATA_HOME=/tmp/caddy

cd "$APP"
su -p -s /bin/sh narratoai -c "unset NARRATOAI_PASSWORD OPENAI_API_KEY; exec streamlit run webui.py \
	--server.address=127.0.0.1 --server.port=8501 --server.headless=true \
	--server.enableCORS=false --server.enableXsrfProtection=true \
	--server.maxUploadSize=${NARRATOAI_MAX_UPLOAD_MB} --server.fileWatcherType=none \
	--browser.gatherUsageStats=false --logger.level=info" &
app=$!
NARRATOAI_PASSWORD_HASH="$NARRATOAI_PASSWORD_HASH" GOMEMLIMIT="${GOMEMLIMIT:-48MiB}" \
	su -p -s /bin/sh narratoai -c 'unset NARRATOAI_PASSWORD OPENAI_API_KEY; exec caddy run --adapter caddyfile --config /opt/narratoai-railway/Caddyfile' &
proxy=$!
unset NARRATOAI_PASSWORD_HASH

stopping=0
term() {
	stopping=1
	kill -TERM "$app" "$proxy" 2>/dev/null || true
}
trap term TERM INT

echo "narratoai-railway: NarratoAI $(cat /opt/narratoai-railway/VERSION) starting (${cpus} CPU, ${limit_mb} MB limit, upload cap ${NARRATOAI_MAX_UPLOAD_MB} MB, data in ${DATA})"
while kill -0 "$app" 2>/dev/null && kill -0 "$proxy" 2>/dev/null; do
	sleep 2 &
	wait $! || true
done

kill -TERM "$app" "$proxy" 2>/dev/null || true
wait "$app" 2>/dev/null || true
wait "$proxy" 2>/dev/null || true
if [ "$stopping" = 1 ]; then
	exit 0
fi
echo "narratoai-railway: a process stopped unexpectedly; exiting 1 so Railway restarts the service" >&2
exit 1
