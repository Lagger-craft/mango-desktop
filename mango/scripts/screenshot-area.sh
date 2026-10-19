#!/usr/bin/env bash
umask 077

if ! geometry=$(slurp -d); then
    exit 0
fi

if [[ -z $geometry ]]; then
    exit 0
fi

screenshots_dir="$HOME/Pictures/Screenshots"
# Owner-only: screenshots routinely contain private content. mkdir -m only
# applies to directories it actually creates, so the mode is set explicitly.
mkdir -p -- "$screenshots_dir"
chmod 700 -- "$screenshots_dir"

timestamp=$(date +%Y%m%d-%H%M%S-%N)
output_file="$screenshots_dir/$timestamp.png"
suffix=1
while [[ -e $output_file ]]; do
    output_file="$screenshots_dir/$timestamp-$suffix.png"
    ((suffix += 1))
done

if grim -g "$geometry" "$output_file"; then
    wl-copy --type image/png < "$output_file"
else
    exit 1
fi
