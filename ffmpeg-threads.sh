#!/bin/sh
# Railway shows every host CPU (32+) inside a 1 vCPU service, and ffmpeg/libx264 size their
# thread pools and frame buffers from that count: a 720p cut was OOM-killed at 0.5 GB.
# This wrapper caps decoder, filter and encoder threads to the service's CPUs, and the
# libx264 lookahead when start.sh sets NARRATOAI_X264_LOOKAHEAD (small services).
real=/usr/bin/ffmpeg
# Works without start.sh's variables too: read the cgroup's CPU and memory limits.
cpus=2
if [ -r /sys/fs/cgroup/cpu.max ]; then
	read -r q p < /sys/fs/cgroup/cpu.max
	[ "$q" != "max" ] && cpus=$(( (q + p - 1) / p ))
fi
[ "$cpus" -lt 1 ] && cpus=1
[ "$cpus" -gt 8 ] && cpus=8
n="${NARRATOAI_FFMPEG_THREADS:-${NARRATOAI_THREADS:-$cpus}}"
if [ -z "${NARRATOAI_X264_LOOKAHEAD+x}" ] && [ -r /sys/fs/cgroup/memory.max ]; then
	read -r m < /sys/fs/cgroup/memory.max
	if [ "$m" != "max" ] && [ $((m / 1048576)) -lt 1500 ]; then NARRATOAI_X264_LOOKAHEAD=10; fi
fi
has_input=0
x264=0
for a; do
	[ "$a" = "-i" ] && has_input=1
	[ "$a" = "libx264" ] && x264=1
done
[ "$has_input" = 1 ] || exec "$real" "$@"
count=$#
i=0
for a; do
	i=$((i + 1))
	if [ "$a" = "-i" ]; then
		set -- "$@" -threads "$n" -i
	elif [ "$i" -eq "$count" ]; then
		if [ "$x264" = 1 ] && [ -n "${NARRATOAI_X264_LOOKAHEAD:-}" ]; then
			set -- "$@" -rc-lookahead "$NARRATOAI_X264_LOOKAHEAD"
		fi
		set -- "$@" -threads "$n" "$a"
	else
		set -- "$@" "$a"
	fi
done
shift "$count"
exec "$real" -filter_threads "$n" -filter_complex_threads "$n" "$@"
