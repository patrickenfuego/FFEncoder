- [FFEncoder](#ffencoder)
  - [About](#about)
  - [Auto-Cropping](#auto-cropping)
  - [Automatic Metadata Fetching](#automatic-metadata-fetching)
  - [Script Parameters](#script-parameters)
  - [Audio Options](#audio-options)
  - [Subtitles](#subtitles)
  - [Requirements](#requirements)
    - [**Windows**](#windows)
    - [**Linux**](#linux)
    - [**MacOS**](#macos)

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

FFEncoder can accept the following arguments from the command line:

| Name           | Default         | Mandatory | Alias                | Description                                                                                                                                           |
| -------------- | --------------- | --------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Test**       | False           | False     | **T**                | Switch to enable a test run. Encodes only 1000 frames starting around the 1 minute mark                                                               |
| **Help**       | False           | False     | **H**, **/?**, **?** | Switch to display help information                                                                                                                    |
| **InputPath**  | None            | True      | **I**                | The path of the source file                                                                                                                           |
| **Audio**      | None (skip)     | False     | **A**                | Audio preference. See the Audio Options section for more information                                                                                  |
| **AacBitrate** | 64 kb/s         | False     | **AQ**, **AACQ**     | AAC audio constant bitrate per channel. If the source is 7.1 (8 CH), then the total bitrate will be 8 \* AacBitrate. Uses FFMpeg's native AAC encoder |
| **Subtitles**  | Default (first) | False     | **S**                | Subtitle passthrough preference. See the Subtitles section for more information                                                                       |
| **Preset**     | slow            | False     | **P**                | The x265 preset to be used. Ranges from placebo (slowest) to ultrafast (fastest)                                                                      |
| **CRF**        | 17.0            | False     | **C**                | Constant rate factor. Ranges from 0.0 to 51.0. Lower value results in higher bitrate                                                                  |
| **Deblock**    | -1,-1           | False     | **DBF**              | Deblock filter. The first value controls the strength, and the second value controls the frequency of use                                             |
| **OutputPath** | None            | True      | **O**                | The path of the encoded output file                                                                                                                   |

&nbsp;

## Audio Options

FFEncoder currently supports the following audio options wih the `-Audio` parameter:

| Type            | Values      | Description                                                                                                                                                                                                         |
| --------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Passthrough** | `copy`, `c` | Passes through the primary audio stream without re-encoding. **Note that copying Dolby Atmos tracks will cause the script to crash** as ffmpeg currently does not have a decoder for it                             |
| **AAC**         | `aac`       | Converts the primary audio stream to AAC using ffmpeg's native CBR encoder. Use the `-AacBitrate` parameter to specify the bitrate **per audio channel**                                                            |
| **AC3**         | `ac3`, `dd` | Dolby Digital. FFEncoder will first scan the input file for an existing AC3 stream. If one is not present, the primary audio stream will be transcoded to AC3                                                       |
| **DTS**         | `dts`       | DTS Core audio. FFEncoder will first scan the input file for an existing DTS stream. If one is not present, the primary audio stream will be transcoded to DTS. **Warning**: ffmpeg's DTS encoder is "experimental" |
| **FLAC**        | `flac`, `f` | Converts the primary audio stream to FLAC lossless audio using ffmpeg's native FLAC encoder                                                                                                                         |
| **None**        | `none`, `n` | Removes all audio streams from the output. This is ideal for object based streams like Dolby Atmos, as it cannot currently be decoded                                                                               |

&nbsp;

## Subtitles

FFEncoder can copy subtitle streams from the input file to the output file using the `-Subtitles` / `s` parameter. I have not added subtitle transcoding because, frankly, ffmpeg is not the best option for this. If you need to convert subtitles from one format to the other, I recommend using [Subtitle Edit](https://www.nikse.dk/SubtitleEdit/) (Windows only, unfortunately).

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

- **ffmpeg** / **ffprobe**
- **PowerShell Core (MacOS/Linux users only)**

&nbsp;

### **Windows**

For Windows users, navigate to the [ffmpeg downloads page](https://ffmpeg.org/download.html#build-windows) and install one of the prebuilt Windows exe packages.

### **Linux**

For Linux users, you can install ffmpeg using your package manager of choice (apt/yum/pacman):

> `apt install ffmpeg`

To install PowerShell core, see Microsoft's instructions for your distribution [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1).

### **MacOS**

For Mac users, the easiest way to install ffmpeg is through the [Homebrew](https://brew.sh/) package manager:

> `brew install ffmpeg`

To install PowerShell Core, run the following command using Homebrew:

> `brew install --cask powershell`
