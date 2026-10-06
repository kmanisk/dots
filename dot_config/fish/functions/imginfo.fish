function imginfo --description "Count photos and videos and calculate total size"
    set -l target "."
    if test (count $argv) -ge 1
        set target $argv[1]
    end
    if not test -d "$target"
        echo "Directory not found: $target"
        return 1
    end
    python3 -c "
import os, sys
target = sys.argv[1]
photo_exts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.heic', '.webp'}
video_exts = {'.mp4', '.mov', '.avi', '.mkv', '.wmv', '.flv', '.webm', '.m4v'}
p_count, p_size = 0, 0
v_count, v_size = 0, 0
for root, _, files in os.walk(target):
    for f in files:
        ext = os.path.splitext(f)[1].lower()
        try:
            sz = os.path.getsize(os.path.join(root, f))
        except OSError:
            continue
        if ext in photo_exts:
            p_count += 1
            p_size += sz
        elif ext in video_exts:
            v_count += 1
            v_size += sz
print(f'Total Photos:      {p_count:,}')
print(f'Total Photo Size:  {p_size / (1024**3):.2f} GB ({p_size / (1024**2):.1f} MB)')
print(f'Total Videos:      {v_count:,}')
print(f'Total Video Size:  {v_size / (1024**3):.2f} GB ({v_size / (1024**2):.1f} MB)')
print(f'Total Media Files: {p_count + v_count:,}')
print(f'Total Media Size:  {(p_size + v_size) / (1024**3):.2f} GB')
" "$target"
end
