====== PicoPad Video Converter Auto ======

Converts video to PicoPad/DemoVGA format for Raspberry Pi Pico RP2040/RP2350.

The output format (VIDEO.VID) contains interleaved video frames (160x240 pixels,
256 colors) and synchronized audio (8-bit mono 22050Hz PCM).


SIMPLIFIED WORKFLOW (using ffmpeg - recommended)
------------------------------------------------
This workflow eliminates the need for XMedia Recode, VirtualDub, and Photoshop.
Just install ffmpeg and run the batch script.

Requirements:
  - ffmpeg (download from https://ffmpeg.org/download.html)
    Make sure ffmpeg.exe is in your PATH or in this directory.
  - PicoPadVideo.exe (the original, unmodified executable from PicoLibSDK)
  - A source video file (e.g. myvideo.mp4)

One-click conversion (recommended):
  1. Place your video file in this directory.
  2. Run: convert.bat myvideo.mp4
  3. Optionally add start time and duration:
       convert.bat myvideo.mp4 00:01:30 30

The script will automatically:
  1. Generate an optimized 256-color palette from the video
  2. Crop the video to 4:3 aspect ratio and export paletted BMP frames
     (160x240, 10fps, with dithering)
  3. Export audio (22050Hz, mono, 8-bit PCM) with a +25% volume boost
  4. Run PicoPadVideo.exe to combine everything into VIDEO.VID

After a successful conversion, intermediate files (BMP/, SOUND.wav, palette.png)
are automatically cleaned up.

Configuration:
  Open convert.bat and edit these lines near the top:

    set CROP_RATIO=4/3
    set CROP_RATIO_INV=3/4
    set VOLUME=1.25

  Wide 16:9 videos are cropped at the sides to fit the 320x240 PicoPad screen.
  Tall videos are cropped at the top/bottom.
  Set VOLUME=1.0 for no volume change.


MANUAL FFMPEG COMMANDS
----------------------
If you prefer to run ffmpeg by hand, the equivalent steps are:

Step 1 - Generate optimized palette:
  ffmpeg -i input.mp4 -vf "framerate=fps=10,crop='min(iw,ih*4/3)':'min(ih,iw*3/4)',scale=160:240:flags=lanczos,palettegen=max_colors=256:stats_mode=full" -y palette.png

Step 2 - Export paletted BMP frames:
  mkdir BMP
  ffmpeg -i input.mp4 -i palette.png -filter_complex "[0:v]framerate=fps=10,crop='min(iw,ih*4/3)':'min(ih,iw*3/4)',scale=160:240:flags=lanczos,vflip[v];[v][1:v]paletteuse=dither=sierra2_4a" -r 10 -start_number 0 "BMP\%06d.bmp"

Step 3 - Export audio:
  ffmpeg -i input.mp4 -af "volume=1.25" -ar 22050 -ac 1 -sample_fmt u8 -acodec pcm_u8 -y SOUND.wav

Step 4 - Convert to PicoPad format:
  PicoPadVideo.exe


OUTPUT FORMAT
-------------
The VIDEO.VID file contains for each frame:
  - 256 palette entries (2 bytes each, RGB565 format) = 512 bytes
  - Pixel data (160 x 240 = 38400 bytes)
  - Audio samples (2205 bytes = 22050 Hz / 10 fps)

The final file can be renamed and used with PicoPad/DemoVGA firmware.


SOURCES AND ADDITIONAL INFO
---------------------------
The original PicoPadVideo.exe was written by Miroslav Nemecek (Panda381) and is
available in his PicoLibSDK under _tools/PicoPadVideo:
  https://github.com/Panda381/PicoLibSDK/tree/main/_tools/PicoPadVideo

The convert.bat script was created to automate the conversion pipeline using
ffmpeg, avoiding the original manual tools.
