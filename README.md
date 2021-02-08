- [FFEncoder](#ffencoder)
  - [About](#about)
  - [Auto-Cropping](#auto-cropping)
  - [Automatic Metadata Fetching](#automatic-metadata-fetching)
  - [Script Parameters](#script-parameters)
  - [Hard Coded Parameters](#hard-coded-parameters)
    - [Exclusive to 4K UHD Content](#exclusive-to-4k-uhd-content)
    - [Exclusive to SDR Content 1080p and Below](#exclusive-to-sdr-content-1080p-and-below)
  - [Audio Options](#audio-options)
    - [Using the libfdk_aac Encoder](#using-the-libfdk_aac-encoder)
  - [Subtitles](#subtitles)
  - [Requirements](#requirements)
    - [Windows](#windows)
    - [Linux](#linux)
    - [MacOS](#macos)

&nbsp;

# FFEncoder

FFEncoder is a cross-platform PowerShell script that is meant to make high definition video encoding easier. FFEncoder uses [ffmpeg](https://ffmpeg.org/), [ffprobe](https://ffmpeg.org/ffprobe.html), and the [x265 HEVC encoder](https://x265.readthedocs.io/en/master/index.html) to compress 4K HDR (3840x2160) video files to be used for streaming or archiving.

&nbsp;

## About

FFEncoder is a simple script that allows you to pass dynamic parameters to ffmpeg without needing to modify things manually for each run. As much as I love ffmpeg/ffprobe, they can be complicated tools to use; the syntax is complex, and some of their commands are not easy to remember unless you use them often. The goal of FFEncoder is to take common encoding workflows and make them easier, while continuing to leverage the power and flexibility of the ffmpeg tool chain.

&nbsp;

## Auto-Cropping

FFEncoder will auto-crop your video, and works similarly to programs like Handbrake. The script uses ffmpeg's `cropdetect` argument to analyze 3 separate 8 minute segments of the source simultaneously. The collected output of each instance is then saved to a crop file which is used to determine the cropping width and height for encoding.

&nbsp;

## Automatic Metadata Fetching

FFEncoder will automatically fetch and fill HDR metadata before encoding begins. This includes:

- Mastering Display Color Primaries (Display P3 and BT.2020 supported)
- Pixel format
- Color Space (Matrix Coefficients)
- Color Primaries
- Color Transfer Characteristics
- Maximum/Minimum Luminance
- Maximum Content Light Level
- Maximum Frame Average Light Level

Color Range (Limited) and Chroma Subsampling (4:2:0) are currently hard coded as they are the same for nearly every source (that I've seen).

&nbsp;

## Script Parameters

FFEncoder can accept the following arguments from the command line. An Asterisk <b>\*</b> denotes that the parameter is required only for its given parameter set (for example, you can choose either CRF or VideBitrate for rate control, but not both):

| Parameter Name    | Default         | Mandatory     | Alias                  | Description                                                                                                                                                         |
| ----------------- | --------------- | ------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Test**          | False           | False         | **T**                  | Switch to enable a test run. Encodes only 1000 frames starting around the 1 minute mark                                                                             |
| **Help**          | False           | <b>\*</b>True | **H**, **/?**, **?**   | Switch to display help information                                                                                                                                  |
| **InputPath**     | None            | True          | **I**                  | The path of the source file                                                                                                                                         |
| **Audio**         | copy (stream 0) | False         | **A**                  | Audio preference for the 1st audio stream in the output file. See [Audio Options](#audio-options) for more information                                              |
| **AudioBitrate**  | None            | False         | **AB**, **ABitrate**   | Parameter to specify bitrate for the chosen audio codec (primary stream). Compatible with AAC, AC3, EAC3, and DTS. See [Audio Options](#audio-options) for defaults |
| **Audio2**        | none (skip)     | False         | **A2**                 | Audio preference for a 2nd audio stream in the output file. See [Audio Options](#audio-options) for more information                                                |
| **AudioBitrate2** | None            | False         | **AB2**, **ABitrate2** | Parameter to specify bitrate for the chosen audio codec (2nd stream). Compatible with AAC, AC3, EAC3, and DTS. See [Audio Options](#audio-options) for defaults     |
| **Subtitles**     | Default (first) | False         | **S**                  | Subtitle passthrough preference. See the Subtitles section for more information                                                                                     |
| **Preset**        | slow            | False         | **P**                  | The x265 preset to be used. Ranges from placebo (slowest) to ultrafast (fastest)                                                                                    |
| **CRF**           | None            | <b>\*</b>True | **C**                  | Constant rate factor rate control setting. Ranges from 0.0 to 51.0. A lower value will result in a higher overall bitrate                                           |
| **VideoBitrate**  | None            | <b>\*</b>True | **Vbitrate**           | Constant bitrate rate control setting. This can be used as an alternative to CRF rate control, and will force the bitrate to the approximate value passed           |
| **Deblock**       | -2, -2          | False         | **DBF**                | Deblock filter. The first value controls the strength, and the second value controls the frequency of use                                                           |
| **AqMode**        | 2               | False         | **AQM**                | x265 AQ mode setting. Ranges from 0 - 4. See x265 documentation for more info on AQ Modes and how they work                                                         |
| **AqStrength**    | 1.00            | False         | **AQS**                | Adjusts the adaptive quantization offsets for AQ. Raising AqStrength higher than 2 will drastically affect the QP offsets, and can lead to high bitrates            |
| **PsyRd**         | 2.00            | False         | **PRD**                | Psycho-visual enhancement. Higher values of PsyRd strongly favor similar energy over blur. See x265 documentation for more info                                     |
| **PsyRdoq**       | 1.00            | False         | **PRDQ**               | Psycho-visual enhancement. Favors high AC energy in the reconstructed image, but it less efficient than PsyRd. See x265 documentation for more info                 |
| **QComp**         | 0.60            | False         | **Q**                  | Sets the quantizer curve compression factor, which effects the bitrate variance throughout the encode. Must be between 0.50 and 1.0                                 |
| **BFrames**       | 4               | False         | **B**                  | The number of B-frames to be used within a GOP. This is especially helpful for test encodes to determine the ideal number of B-frames to use                        |
| **OutputPath**    | None            | True          | **O**                  | The path of the encoded output file                                                                                                                                 |

&nbsp;

## Hard Coded Parameters

I am a bit opinionated about certain settings, so the following parameters are hard coded (they can be changed manually):

- `subme=4` - This is the default for the veryslow preset, and I find that it gives better high motion clarity without too much of a performance hit. I plan to add a parameter for this sometime soon
- `no-sao` - I really hate the way sao looks, so it's disabled along with `selective-sao`. There's a reason it has earned the moniker "smooth all objects", and it makes everything look waxy in my opinion
- `rc-lookahead=48` - People are all over the board with this, but I have found 48 (2 \* 24 fps, or effectively, 2 \* fps) to be a number with good gains and no diminishing returns. This is recommended by many experienced folks at the [doom9 forum](https://forum.doom9.org/showthread.php?t=175993)
- `keyint-120` - This is personal preference. I like to spend a few extra bits to insert more I-frames into a GOP, which helps with seeking (fast-forwarding, rewinding) through the video. This could be raised to 240 without much issue
- `no-open-gop` - The UHD BD specification recommends that closed GOPs be used. in general, closed GOPs are preferred for streaming content. x264 had closed GOPs by default. For more insight, listen to what famed compressionist [Ben Waggoner](https://streaminglearningcenter.com/articles/open-and-closed-gops-all-you-need-to-know.html) has to say on the topic

### Exclusive to 4K UHD Content

- `level-idc=5.1`, `high tier=1` - I have found this to be ideal for 4K content as `Main 10@L5@Main` only allows for a maximum bitrate of 25 mb/s (and 4K content sometimes exceeds this, especially if there is a lot of grain)

### Exclusive to SDR Content 1080p and Below

- `merange` - The default value of 57 is a bit much for 1080p content, and it slows the encode with no noticeable gain. Value is set to 44. For 720p content, merange could lowered even more to 26

&nbsp;

## Audio Options

FFEncoder now supports the mapping/transcoding of 2 distinct audio streams to the output file. For audio that is transcoded, the primary audio stream is used, as this stream is generally lossless (TrueHD, DTS-HD MA, LPCM, etc.). **It is never recommended to transcode from one lossy codec to another**.

FFEncoder currently supports the following audio options wih the `-Audio`/`-Audio2` parameters. If the `-AudioBitrate`/`-AudioBitrate2` parameters are present, the chosen codec will be transcoded at that bitrate. Otherwise, FFEncoder will scan the input for an existing stream which matches the `-Audio` parameter input and copy it; if one is not found, the primary stream will be transcoded to the selected format at the default bitrates listed below:

**NOTE:** To copy Dolby Atmos streams, you **must** be using the latest ffmpeg build, **or the script will fail**

| Type         | Values           | Default        | Description                                                                                                                            |
| ------------ | ---------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Copy**     | `copy`, `c`      | N/A            | Passes through the primary audio stream without re-encoding                                                                            |
| **Copy All** | `copyall`, `ca`  | N/A            | Passes through all audio streams from the input to the output without re-encoding                                                      |
| **AAC**      | `aac`            | 512 kb/s       | Converts the primary audio stream to AAC using ffmpeg's native CBR encoder. Compatible with the `-AudioBitrate` parameter              |
| **FDK AAC**  | `fdkaac`, `faac` | Variable (VBR) | Converts the primary audio stream to AAC using libfdk_aac. Compatible with the `-AudioBitrate` parameter. See note below for more info |
| **AC3**      | `ac3`, `dd`      | 640 kb/s       | Dolby Digital. Compatible with the `-AudioBitrate` parameter                                                                           |
| **E-AC3**    | `ac3`, `dd`      | 448 kb/s       | Dolby Digital Plus. Compatible with the `-AudioBitrate` parameter                                                                      |
| **DTS**      | `dts`            | Variable (VBR) | DTS Core audio. **Warning**: ffmpeg's DTS encoder is "experimental". Compatible with the `-AudioBitrate` parameter                     |
| **FLAC**     | `flac`, `f`      | Variable (VBR) | Converts the primary audio stream to FLAC lossless audio using ffmpeg's native FLAC encoder                                            |
| **None**     | `none`, `n`      | N/A            | Removes all audio streams from the output. This is ideal for object based streams like Dolby Atmos, as it cannot currently be decoded  |

&nbsp;

### Using the libfdk_aac Encoder

FFEncoder includes support for Fraunhofer's libfdk_aac, even though it is not included in a standard ffmpeg executable. Due to a conflict with ffmpeg's LGPL license, libfdk_aac cannot be distributed with any official ffmpeg binaries, but it can be included when compiling ffmpeg manually from source. For more information on compiling from source, see [Requirements](#requirements). 

&nbsp;

## Subtitles

FFEncoder can copy subtitle streams from the input file to the output file using the `-Subtitles` / `s` parameter. I have not added subtitle transcoding because, frankly, ffmpeg is not the best option for this. If you need to convert subtitles from one format to the other, I recommend using [Subtitle Edit](https://www.nikse.dk/SubtitleEdit/) (Windows only).

The different parameter options are:

- `default` / `d` - Copies the default (primary) subtitle stream from the input file
- `all` / `a` - Copies all subtitle streams from the input file
- `none` / `n` - Excludes subtitles from the output entirely
- **Language** - You can also specify a language to copy, and FFEncoder will search the input for all corresponding subtitles. If the specified language isn't found, no subtitle streams will be copied. The following languages are supported (use the language code on the right):
  - English - `eng`
  - French - `fre`
  - German - `ger`
  - Spanish - `spa`
  - Dutch - `dut`
  - Danish - `dan`
  - Finnish - `fin`
  - Norwegian - `nor`
  - Czech - `cze`
  - Polish - `pol`
  - Chinese - `chi`
  - Korean - `kor`
  - Greek - `gre`
  - Romanian - `rum`

&nbsp;

## Requirements

- ffmpeg / ffprobe
- PowerShell Core (MacOS/Linux users only)

&nbsp;

**NOTE:** You can compile ffmpeg manually from source on all platforms, which allows you to select additional libraries (such as Fraunhofer's libfdk AAC encoder). For more information, see [here](https://trac.ffmpeg.org/wiki/CompilationGuide)

&nbsp;

### Windows

For Windows users, navigate to the [ffmpeg downloads page](https://ffmpeg.org/download.html#build-windows) and install one of the prebuilt Windows exe packages.

### Linux

For Linux users, you can install ffmpeg using your package manager of choice (apt/yum/pacman):

> `apt install ffmpeg`

To install PowerShell core, see Microsoft's instructions for your distribution [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1).

### MacOS

For Mac users, the easiest way to install ffmpeg is through the [Homebrew](https://brew.sh/) package manager:

> `brew install ffmpeg`

To install PowerShell Core, run the following command using Homebrew:

> `brew install --cask powershell`
