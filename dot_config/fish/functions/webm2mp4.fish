function webm2mp4 --description "Convert WebM to MP4 with high quality using ffmpeg"
    set -l input $argv[1]
    if not test -f "$input"
        echo "File not found: $input"
        return 1
    end
    set -l output (string replace -r '\.webm$' '.mp4' "$input")
    echo "Converting $input -> $output..."
    ffmpeg -hide_banner -loglevel error -stats -i "$input" \
        -map 0:v:0 -map 0:a:0? -c:v libx264 -preset slow -crf 18 \
        -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 192k -ac 2 "$output"
    if test $status -eq 0
        echo "✔ Done: $output"
    else
        echo "✖ ffmpeg failed for $input"
    end
end
