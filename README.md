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

FFEncoder can accept the following arguments from the command line. An Asterisk <b>\*</b> denotes that the parameter is required only for its given parameter set (for example, you can choose either CRF or VideBitrate for rate control, but not both):

| Parameter Name   | Default         | Mandatory     | Alias                | Description                                                                                                                                                            |
| ---------------- | --------------- | ------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Test**         | False           | <b>\*</b>True | **T**                | Switch to enable a test run. Encodes only 1000 frames starting around the 1 minute mark                                                                                |
| **Help**         | False           | False         | **H**, **/?**, **?** | Switch to display help information                                                                                                                                     |
| **InputPath**    | None            | True          | **I**                | The path of the source file                                                                                                                                            |
| **Audio**        | None (skip)     | False         | **A**                | Audio preference. See the Audio Options section for more information                                                                                                   |
| **AudioBitrate** | None            | False         | **AB**, **ABitrate** | Optional parameter to specify a constant bitrate for the chosen audio codec. Compatible with AAC, AC3, EAC3, and DTS. See [Audio Options](#audio-options) for defaults |
| **Subtitles**    | Default (first) | False         | **S**                | Subtitle passthrough preference. See the Subtitles section for more information                                                                                        |
| **Preset**       | slow            | False         | **P**                | The x265 preset to be used. Ranges from placebo (slowest) to ultrafast (fastest)                                                                                       |
| **CRF**          | None            | <b>\*</b>True | **C**                | Constant rate factor rate control setting. Ranges from 0.0 to 51.0. A lower value will result in a higher overall bitrate                                              |
| **VideoBitrate** | None            | <b>\*</b>True | **Vbitrate**         | Constant bitrate rate control setting. This can be used as an alternative to CRF rate control, and will force the bitrate to the approximate value passed              |
| **Deblock**      | -1, -1          | False         | **DBF**              | Deblock filter. The first value controls the strength, and the second value controls the frequency of use                                                              |
| **AqMode**       | 2               | False         | **AQM**              | x265 AQ mode setting. Ranges from 0 - 4. See x265 documentation for more info on AQ Modes and how they work                                                            |
| **AqStrength**   | 1.00            | False         | **AQS**              | Adjusts the adaptive quantization offsets for AQ. Raising AqStrength higher than 2 will drastically affect the QP offsets, and can lead to high bitrates               |
| **PsyRd**        | 2.00            | False         | **PRD**              | Psycho-visual enhancement. Higher values of PsyRd strongly favor similar energy over blur. See x265 documentation for more info                                        |
| **PsyRdoq**      | 1.00            | False         | **PRDDQ**            | Psycho-visual enhancement. Favors high AC energy in the reconstructed image, but it less efficient than PsyRd. See x265 documentation for more info                    |
| **OutputPath**   | None            | True          | **O**                | The path of the encoded output file                                                                                                                                    |

&nbsp;

## Audio Options

FFEncoder currently supports the following audio options wih the `-Audio` parameter. If the `-AudioBitrate` parameter is present, the chosen codec will be transcoded at that bitrate. Otherwise, FFEncoder will scan the input for an existing stream which matches the `-Audio` parameter input and copy it; if one is not found, the primary stream will be transcoded to the selected format at the default bitrates listed below:

| Type         | Values          | Default        | Description                                                                                                                                                                                                                                                        |
| ------------ | --------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Copy**     | `copy`, `c`     | N/A            | Passes through the primary audio stream without re-encoding. **Note that copying Dolby Atmos tracks will cause the script to crash** as ffmpeg does not have a decoder for it                                                                                      |
| **Copy All** | `copyall`, `ca` | N/A            | Passes through all audio streams from the input to the output without re-encoding                                                                                                                                                                                  |
| **AAC**      | `aac`           | 512 kb/s       | Converts the primary audio stream to AAC using ffmpeg's native CBR encoder. Compatible with the `-AudioBitrate` parameter                                                                                                                                          |
| **AC3**      | `ac3`, `dd`     | 640 kb/s       | Dolby Digital. FFEncoder will first scan the input file for an existing AC3 stream. If one is not present, the primary audio stream will be transcoded to AC3. Compatible with the `-AudioBitrate` parameter                                                       |
| **E-AC3**    | `ac3`, `dd`     | 448 kb/s       | Dolby Digital Plus. FFEncoder will first scan the input file for an existing E-AC3 stream. If one is not present, the primary audio stream will be transcoded to E-AC3. Compatible with the `-AudioBitrate` parameter                                              |
| **DTS**      | `dts`           | Variable (VBR) | DTS Core audio. FFEncoder will first scan the input file for an existing DTS stream. If one is not present, the primary audio stream will be transcoded to DTS. **Warning**: ffmpeg's DTS encoder is "experimental". Compatible with the `-AudioBitrate` parameter |
| **FLAC**     | `flac`, `f`     | Variable (VBR) | Converts the primary audio stream to FLAC lossless audio using ffmpeg's native FLAC encoder                                                                                                                                                                        |
| **None**     | `none`, `n`     | N/A            | Removes all audio streams from the output. This is ideal for object based streams like Dolby Atmos, as it cannot currently be decoded                                                                                                                              |

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
