#!/bin/sh
# Railway shows every host CPU (32+) inside a 1 vCPU service, and ffmpeg/libx264 size their
# thread pools and frame buffers from that count: a 720p cut was OOM-killed at 0.5 GB.
# This wrapper caps decoder, filter and encoder threads to the service's CPUs, and the
# libx264 lookahead when start.sh sets NARRATOAI_X264_LOOKAHEAD (small services).
real=/usr/bin/ffmpeg
n="${NARRATOAI_FFMPEG_THREADS:-${NARRATOAI_THREADS:-2}}"
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
