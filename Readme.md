# PicoPad Video Converter Auto

This is an automatic batch script that converts MP4 video for use with the PicoPadSDK video player (for Raspberry Pi Pico RP2040 & RP2350).

The output format (`VIDEO.VID`) contains interleaved video frames (160×240 pixels, 256 colors) and synchronized audio (8-bit mono 22050 Hz PCM).

## Requirements

- `ffmpeg.exe` in this directory or in your system `PATH`  
  *(download from [ffmpeg.org](https://ffmpeg.org/download.html))*
- `PicoPadVideo.exe` — the executable from the [PicoLibSDK](https://github.com/Panda381/PicoLibSDK/tree/main/_tools/PicoPadVideo)
- A source video file (e.g. `myvideo.mp4`)

## Simplified Workflow (using ffmpeg)

This workflow replaces the original manual steps using **XMedia Recode**, **VirtualDub**, and **Photoshop**. You only need `ffmpeg` and the original `PicoPadVideo.exe`.

### One-click conversion

```batch
convert.bat myvideo.mp4
```

Optional start time and duration:

```batch
convert.bat myvideo.mp4 00:01:30 30
```

### What the script does

1. Generates an optimized 256-color palette from the video
2. Crops the video to a **4:3** aspect ratio and exports paletted BMP frames (160×240, 10 fps, with dithering)
3. Exports audio (22050 Hz, mono, 8-bit PCM) with a **+25% volume boost**
4. Runs `PicoPadVideo.exe` to combine everything into `VIDEO.VID`

After a successful conversion, intermediate files (`BMP/`, `SOUND.wav`, `palette.png`) are automatically cleaned up.

### Configuration

Open `convert.bat` and edit these lines near the top:

```batch
:: Target display aspect ratio (width/height). Use 4/3 for the 320x240 PicoPad screen.
set CROP_RATIO=4/3
set CROP_RATIO_INV=3/4

:: Audio volume multiplier (1.0 = original, 1.25 = 25%% louder)
set VOLUME=1.25
```

### Notes

- Wide 16:9 videos are cropped at the sides to fit the 320×240 PicoPad screen without stretching.
- Tall videos are cropped at the top/bottom.
- ffmpeg warnings such as **"Late SEI is not implemented"** are hidden automatically to keep the output readable.

## Manual ffmpeg commands

If you prefer to run ffmpeg by hand, the equivalent steps are:

### Step 1: Generate optimized palette

```batch
ffmpeg -i input.mp4 -vf "framerate=fps=10,crop='min(iw,ih*4/3)':'min(ih,iw*3/4)',scale=160:240:flags=lanczos,palettegen=max_colors=256:stats_mode=full" -y palette.png
```

### Step 2: Export paletted BMP frames

```batch
mkdir BMP
ffmpeg -i input.mp4 -i palette.png -filter_complex "[0:v]framerate=fps=10,crop='min(iw,ih*4/3)':'min(ih,iw*3/4)',scale=160:240:flags=lanczos[v];[v][1:v]paletteuse=dither=sierra2_4a" -r 10 -start_number 0 "BMP\%06d.bmp"
```

### Step 3: Export audio

```batch
ffmpeg -i input.mp4 -af "volume=1.25" -ar 22050 -ac 1 -sample_fmt u8 -acodec pcm_u8 -y SOUND.wav
```

### Step 4: Convert to PicoPad format

```batch
PicoPadVideo.exe
```

## Output Format

The `VIDEO.VID` file contains for each frame:

- 256 palette entries (2 bytes each, RGB565) = 512 bytes
- Pixel data (160 × 240 = 38,400 bytes)
- Audio samples (2205 bytes = 22050 Hz ÷ 10 fps)

The final file can be renamed and used with PicoPad/DemoVGA firmware.


## Files included

| File | Description |
|------|-------------|
| `convert.bat` | One-click ffmpeg-based conversion script |
| `Readme.md` | This file |
| `Readme.txt` | Plain-text readme |
| `.gitignore` | Git ignore rules |

## Sources and additional info

The original `PicoPadVideo.exe` was written by Miroslav Nemecek (Panda381) and is available in his PicoLibSDK under [_tools/PicoPadVideo](https://github.com/Panda381/PicoLibSDK/tree/main/_tools/PicoPadVideo).

The `convert.bat` script was created to automate the conversion pipeline using ffmpeg, avoiding the original manual tools. My idea, but implemented using Kimi K2.7 code/Freebuff. Welcome to the future.

## Future improvements

- **Pipe mode**: It may be possible to skip the intermediate BMP files entirely by piping a stream of raw BMP frames directly into `PicoPadVideo.exe`. This would require modifying the source to read frames from stdin, but could speed up conversion and reduce disk I/O.
