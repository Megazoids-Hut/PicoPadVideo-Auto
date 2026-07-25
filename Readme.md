# PicoPad Video Converter Auto

This is an automatic bat file script that converts MP4 video for use with the PicoPadSDK video player (for Raspberry Pi Pico RP2040 & RP2350). This script uses a modfiled version of PicoPadVideo.exe.

The output format (`VIDEO.VID`) contains interleaved video frames (160×240 pixels, 256 colors) and synchronized audio (8-bit mono 22050 Hz PCM).

## Simplified Workflow (using ffmpeg — recommended)

This workflow replaces the [original manual steps](https://github.com/Panda381/PicoLibSDK/blob/main/_tools/PicoPadVideo/Readme.txt) using **XMedia Recode**, **VirtualDub**, and **Photoshop**. You only need [ffmpeg](https://ffmpeg.org/download.html) and the compiled `PicoPadVideo.exe`.

### Requirements

- `ffmpeg.exe` in this directory or in your system `PATH`  
  *(download from [ffmpeg.org](https://ffmpeg.org/download.html) — do not commit it to Git)*
- `PicoPadVideo.exe` (build from `PicoPadVideo.sln` or use the existing build)
- A source video file (e.g. `myvideo.mp4`)

### One-click conversion

```batch
convert.bat myvideo.mp4
```

Optional start time and duration:

```batch
convert.bat myvideo.mp4 00:01:30 30
```

The script will:

1. Generate an optimized 256-color palette from the video
2. Export paletted BMP frames (160×240, 10 fps, with dithering)
3. Export audio (22050 Hz, mono, 8-bit PCM)
4. Run `PicoPadVideo.exe` to combine everything into `VIDEO.VID`

After a successful conversion, intermediate files (`BMP/`, `SOUND.wav`, `palette.png`) are automatically cleaned up.

## Manual ffmpeg commands

If you prefer to run ffmpeg by hand, the equivalent steps are:

### Step 1: Generate optimized palette

```batch
ffmpeg -i input.mp4 -vf "framerate=fps=10,scale=160:240:flags=lanczos,palettegen=max_colors=256:stats_mode=full" -y palette.png
```

### Step 2: Export paletted BMP frames

```batch
mkdir BMP
ffmpeg -i input.mp4 -i palette.png -filter_complex "[0:v]framerate=fps=10,scale=160:240:flags=lanczos,vflip[v];[v][1:v]paletteuse=dither=sierra2_4a" -r 10 -start_number 0 "BMP\%06d.bmp"
```

### Step 3: Export audio

```batch
ffmpeg -i input.mp4 -ar 22050 -ac 1 -sample_fmt u8 -acodec pcm_u8 SOUND.wav
```

### Step 4: Convert to PicoPad format

```batch
PicoPadVideo.exe
```

### Optional: Pipe mode

You can also convert without writing intermediate BMP files by piping raw BMP data directly into `PicoPadVideo.exe`:

```batch
ffmpeg -i input.mp4 -i palette.png -filter_complex "[0:v]framerate=fps=10,scale=160:240:flags=lanczos,vflip[v];[v][1:v]paletteuse=dither=sierra2_4a" -r 10 -f image2pipe -c:v bmp - | PicoPadVideo.exe -pipe
```

Pipe mode reads BMP frames from stdin and produces `VIDEO.VID` directly.

## Legacy Workflow

If you prefer the original manual method using XMedia Recode, VirtualDub, and Photoshop, see the [original](https://github.com/Panda381/PicoLibSDK/blob/main/_tools/PicoPadVideo/]

## Output Format

The `VIDEO.VID` file contains for each frame:

- 256 palette entries (2 bytes each, RGB565) = 512 bytes
- Pixel data (160 × 240 = 38,400 bytes)
- Audio samples (2205 bytes = 22050 Hz ÷ 10 fps)

The final file can be renamed and used with PicoPad/DemoVGA firmware.

## Building from source

Open `PicoPadVideo.sln` in Visual Studio and build. The project is a simple console application written in C.

## Files included

| File | Description |
|------|-------------|
| `PicoPadVideo.cpp` | Source code for the converter |
| `PicoPadVideo.sln` | Visual Studio solution |
| `PicoPadVideo.vcproj` | Visual Studio project |
| `convert.bat` | One-click ffmpeg-based conversion script |
| `Readme.md` | This file |
| `Readme.txt` | Legacy text readme |
| `.gitignore` | Git ignore rules |

## Sources and additional info

This project was coded by Kimi K2.7 code (Ai) via [Freebuff](https://freebuff.com) based on an idea I thought was possible (to do most stages via ffmpeg). The original PicoPadVideo.exe was written by Miroslav Nemecek (Panda381) and is available on his PicoPadSDK under [_tools/PicoPadVideo](https://github.com/Panda381/PicoLibSDK/tree/main/_tools/PicoPadVideo).

PicoPadVideo.cpp has been modified. The changes were:
1. Pipe mode — added a  -pipe  command-line argument so it can read raw BMP data from an  ffmpeg  pipe
2. Refactored BMP reading — pulled the BMP parsing into a  read_and_process_bmp()  function used by both file mode and pipe mode
3. BMP boundary-safe reading — reads the 14-byte BMP header first, gets the exact file size, then reads the rest, so pipe mode doesn't accidentally cross frame boundaries
