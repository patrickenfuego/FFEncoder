# FFEncoder

FFEncoder is a PowerShell script that is meant to make high definition video encoding easier. FFEncoder uses [ffmpeg](https://ffmpeg.org/) and the [x265 HEVC encoder](https://x265.readthedocs.io/en/master/index.html) to compress 4K HDR (3840x2160) video files to be used for streaming or archiving.

## About

FFEncoder is a simple script that allows you to pass dynamic parameters to ffmpeg without needing to modify things manually for each run.

FFEncoder will auto-crop your video, and works similarly to programs like Handbrake. The script uses ffmpeg's `cropdetect` argument to analyze 3 separate 8 minute segments of the source simultaneously. The collected output of each instance is then saved to a crop file which is used to determine the cropping width and height for encoding.

FFEncoder will also automatically fetch and fill HDR metadata before encoding begins. This includes:

- Mastering Display Color Primaries (Display P3 and BT.2020 supported)
- Pixel format
- Color Space (Matrix Coefficients)
- Color Primaries
- Color Transfer Characteristics
- Maximum/Minimum Luminance
- Maximum Content Light Level
- Maximum Frame Average Light Level

Color Range (Limited) and Chroma Subsampling (4:2:0) are currently hard coded as they are the same for nearly every source.

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

## Development

My future plans for this script, in the order that they are likely to occur:

- 1080p HDR support
- Add additional commonly modified parameters for x265, like:
  - `aq-mode` - FFEncoder uses 2, but for 1080p encodes, 3 is usually preferred. I will add a parameter for it when I add 1080p.
  - `aq-strength` - This can be helpful for controlling bitrate when encoding 1080p sources, so I will add a parameter for it.
  - `tier` - FFEncoder currently uses Main10 profile, level 5.1 @ high tier. For 1080p encodes, high tier isn't necessary, so I'll add a switch to disable it.
  - `subme` - My current default is 4, and this is what FFEncoder also uses. Sometimes I prefer a lower/higher value for performance reasons, so it's on the list.
  - `psy-rd` - For 4K, I usually leave it at default (2.00), but I will add a parameter for it in the future.
  - `psy-rdoq` - Like psy-rd, the default is usually fine. With sources that have a lot of grain, though, a parameter would be helpful.
  - `dhdr10` - Whenever I get a source that has Dynamic HDR, this parameter will get added.
- 2160p SDR support
- 1080p SDR support
- Support for batch jobs

I am also currently working on a cross platform GUI interface as well.
