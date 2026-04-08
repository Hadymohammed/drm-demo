ffmpeg -f avfoundation -framerate 30 -i "0" \
  -filter_complex "\
    [0:v]split=2[src1][src2]; \
    [src1]scale=256:144,split=2[v1dash][v1hls]; \
    [src2]scale=320:240,split=2[v2dash][v2hls]" \
  \
  -map "[v1dash]" -c:v:0 libx264 -b:v:0 300k \
  -map "[v2dash]" -c:v:1 libx264 -b:v:1 800k \
  \
  -preset veryfast -tune zerolatency \
  -pix_fmt yuv420p \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  \
  -f dash \
  -seg_duration 2 \
  -use_template 1 \
  -use_timeline 1 \
  -window_size 0 \
  -extra_window_size 0 \
  -streaming 1 \
  -ldash 1 \
  -utc_timing_url "https://time.akamai.com/?iso" \
  cdn/storage/live/dash/manifest.mpd \
  \
  -map "[v1hls]" -c:v:0 libx264 -b:v:0 300k \
  -map "[v2hls]" -c:v:1 libx264 -b:v:1 800k \
  -f hls \
  -hls_time 2 \
  -hls_list_size 5 \
  -hls_flags delete_segments \
  -var_stream_map "v:0,name:144p v:1,name:240p" \
  -master_pl_name master.m3u8 \
  cdn/storage/live/hls/stream_%v.m3u8