# FFEncoder

FFEncoder is a PowerShell script that is meant to make high definition video encoding easier. FFEncoder uses [ffmpeg](https://ffmpeg.org/), [ffprobe](https://ffmpeg.org/ffprobe.html), and the [x265 HEVC encoder](https://x265.readthedocs.io/en/master/index.html) to compress 4K HDR (3840x2160) video files to be used for streaming or archiving.

## About

FFEncoder is a simple script that allows you to pass dynamic parameters to ffmpeg without needing to modify things manually for each run. As much as I love ffmpeg/ffprobe, they can be complicated tools to use; the syntax is complex, and some of their commands are not easy to remember unless you use them often. The goal of FFEncoder is to take common workflows and make them easier, which continuing to leverage the power and flexibility of the tools.

## Auto-Cropping

FFEncoder will auto-crop your video, and works similarly to programs like Handbrake. The script uses ffmpeg's `cropdetect` argument to analyze 3 separate 8 minute segments of the source simultaneously. The collected output of each instance is then saved to a crop file which is used to determine the cropping width and height for encoding.

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

## Audio Options

FFEncoder currently supports the following audio options wih the `-Audio` parameter, and more will be added soon:

- **Audio Passthrough** - This option passes through the primary audio stream without re-encoding. Supported arguments are `copy`/ `c`. Note that copying **Dolby Atmos tracks will cause the script to crash** as ffmpeg currently does not have a decoder for it. See the script's help comments for more information
- **AAC Audio** - This options converts the primary audio stream to AAC using ffmpeg's native AAC encoder and the supported argument is `aac`. The encoder uses constant bit rate (CBR) instead of variable bit rate (VBR), as ffmpeg's documentation states that the VBR encoder is experimental, and likely to give poor results. You can use the `-AacBitrate` parameter to specify the bitrate **per audio channel**; for example, if the source is 7.1 (8 channels), the total bitrate will be 8 * the `AacBitrate` parameter value. Default is 64 kb/s per channel.
- **No Audio** - This option removes all audio streams from the output. This is ideal for object based formats like Dolby Atmos, as they cannot be decoded. I have seen DTS-X get passed without issues, but I have not tested it on an AV receiver yet. In these situations, I use tools like [MkvToolNix](https://mkvtoolnix.download) to mux out the audio stream and add it back in to my final encode. This is the default behavior of FFEncoder. Supported arguments are `none`/`n`.



## Script Arguments

FFEncoder can accept the following arguments from the command line:

| Name           | Default     | Mandatory | Alias                | Description                                                                                                                                           |
| -------------- | ----------- | --------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Test**       | False       | False     | **T**                | Switch to enable a test run. Encodes only 1000 frames starting around the 1 minute mark                                                               |
| **Help**       | False       | False     | **H**, **/?**, **?** | Switch to display help information                                                                                                                    |
| **InputPath**  | None        | True      | **I**                | The path of the source file                                                                                                                           |
| **Audio**      | None (skip) | False     | **A**                | Audio preference. Options are _none_/_n_, _copy_/_c_, or _aac_. AAC uses ffmpeg's native encoder at a constant bitrate (CBR)                          |
| **AacBitrate** | 64 kb/s     | False     | **AQ**, **AACQ**     | AAC audio constant bitrate per channel. If the source is 7.1 (8 CH), then the total bitrate will be 8 \* AacBitrate. Uses FFMpeg's native AAC encoder |
| **Preset**     | slow        | False     | **P**                | The x265 preset to be used. Ranges from placebo (slowest) to ultrafast (fastest)                                                                      |
| **CRF**        | 16.0        | False     | **C**                | Constant rate factor. Ranges from 0.0 to 51.0. Lower value results in higher bitrate                                                                  |
| **Deblock**    | -1,-1       | False     | **DBF**              | Deblock filter. The first value controls the strength, and the second value controls the frequency of use                                             |
| **OutputPath** | None        | True      | **O**                | The path of the encoded output file                                                                                                                   |

## Requirements

- <b>ffmpeg</b> / **ffprobe**
- <b>PowerShell Core (MacOS/Linux users only)</b>

### **Windows**

For Windows users, navigate to the [ffmpeg downloads page](https://ffmpeg.org/download.html#build-windows) and install one of the prebuilt Windows exe packages.

### **Linux**

For Linux users, you can install ffmpeg using your package manager of choice (apt/yum/pacman):

> `apt install ffmpeg`

To install PowerShell core, see Microsoft's instructions for your distribution [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1).

### **MacOS**

For Mac users, the easiest way to install ffmpeg is through the [Homebrew](https://brew.sh/) package manager:

> `brew install ffmpeg`

To install PowerShell core, run the following command using Homebrew:

> `brew install --cask powershell`

