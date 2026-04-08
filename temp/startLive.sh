ffmpeg -f avfoundation -framerate 30 -i "0" \
  -c:v libx264 \
  -preset veryfast \
  -tune zerolatency \
  -keyint_min 60 -g 60 -sc_threshold 0 \
  -pix_fmt yuv420p \
  -f segment \
  -segment_time 2 \
  -segment_format mpegts \
  cdn/storage/live/raw/segment_%03d.ts