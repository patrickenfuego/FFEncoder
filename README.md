# FFEncoder

FFEncoder is a cross-platform PowerShell script and module that is meant to make high definition video encoding easier. FFEncoder uses [ffmpeg](https://ffmpeg.org/), [ffprobe](https://ffmpeg.org/ffprobe.html), and the [x265 HEVC encoder](https://x265.readthedocs.io/en/master/index.html) to compress video files for streaming or archiving.

- [FFEncoder](#ffencoder)
  - [About](#about)
  - [Dependencies](#dependencies)
  - [Dependency Installation](#dependency-installation)
    - [Windows](#windows)
    - [Linux](#linux)
    - [macOS](#macos)
  - [Auto-Cropping](#auto-cropping)
  - [Automatic HDR Metadata](#automatic-hdr-metadata)
  - [Rate Control Options](#rate-control-options)
  - [Script Parameters](#script-parameters)
    - [**Mandatory**](#mandatory)
    - [**Utility**](#utility)
    - [**Audio & Subtitles**](#audio--subtitles)
    - [**Video Filtering**](#video-filtering)
    - [**Encoder Config**](#encoder-config)
    - [**x265 Settings**](#x265-settings)
    - [**Extra**](#extra)

---

## About

FFEncoder is a simple script that allows you to pass dynamic parameters to ffmpeg without needing to modify complicated CLI arguments for each source. As much as I love the ffmpeg suite, it can be complicated to learn and use; the syntax is extensive, and many of the arguments are not easy to remember unless you use them often. The goal of FFEncoder is to take common encoding workflows and make them easier, while continuing to leverage the power and flexibility of the ffmpeg tool chain.

Check out the [wiki](https://github.com/patrickenfuego/FFEncoder/wiki) for additional information.

---

## Dependencies

- ffmpeg / ffprobe
- PowerShell v. 7.0 or newer

The script requires PowerShell Core 7.0 or newer on all systems as it utilizes new parallel processing features introduced in this version. Multi-threading prior to PowerShell 7 was prone to memory leaks which persuaded me to make the change.

`mkvmerge` and `mkvextract` from [Mkvtoolnix](https://mkvtoolnix.download/) are **recommended**, but not required.

> For Windows users, PowerShell Core is a supplemental installation and will will be installed alongside PowerShell 5.1

---

## Dependency Installation

> You can compile ffmpeg manually from source on all platforms, which allows you to select additional libraries (like Fraunhofer's libfdk AAC encoder). For more information, see [here](https://trac.ffmpeg.org/wiki/CompilationGuide)

### Windows

To download ffmpeg, navigate to the [ffmpeg downloads page](https://ffmpeg.org/download.html#build-windows) and install one of the prebuilt Windows exe packages. I recommend the builds provided by Gyan.

To install the latest version of PowerShell Core, follow the instructions provided by Microsoft [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7.1).

### Linux

You can install ffmpeg using your distro's package manager (apt/yum/pacman/zypper):

```shell
apt install ffmpeg
```

To install PowerShell, see Microsoft's instructions for your distribution [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1).

### macOS

The easiest way to install ffmpeg and PowerShell core is through the [Homebrew](https://brew.sh/) package manager:

```shell
brew install ffmpeg
```

One of the other benefits of using Homebrew is that you can easily install a build that includes non-free libraries like fdk_aac:

```shell
brew install ffmpeg --with-fdk-aac
```

To install PowerShell, run the following command using Homebrew:

```shell
brew install --cask powershell
```

---

## Auto-Cropping

> **NOTE**: FFEncoder uses modulus 2 rounding to detect black borders. I've found this to be the most consistent choice for the majority content. If you do not want the script to auto-crop your video, you may pass **override crop values** via the `-FFMpegExtra` parameter (see [here](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#overriding-crop-arguments) for more info)

FFEncoder will auto-crop your video, and works similarly to programs like [Handbrake](https://handbrake.fr/) with more emphasis on accuracy. The script analyzes up to 6 separate segments of the source simultaneously, collects the output, and saves it to a file which is used to determine cropping values for encoding.

---

## Automatic HDR Metadata

FFEncoder will automatically fetch and fill HDR metadata before encoding begins. This includes:

> **NOTE**: Color Range (Limited) and Chroma Subsampling (4:2:0) are currently hard coded as they are the same for all Blu-Ray sources. If you need dynamic parameters, put in a feature request and I will add them.

- Mastering Display Color Primaries
- Pixel format
- Color Space (Matrix Coefficients)
- Color Primaries
- Color Transfer Characteristics
- Maximum/Minimum Luminance
- Maximum Content Light Level
- Maximum Frame Average Light Level
- HDR10+ Metadata
- Dolby Vision Metadata
  - Requires `x265` to be available via PATH (**Executable must be named x265**) because ffmpeg cannot handle RPU files
  - Currently, only profile 8.1 is supported due it it's backwards compatibility with HDR10
  - It is recommended to have `mkvmerge`/`mkvextract` available. The script will multiplex tracks back together after encoding

---

## Rate Control Options

FFEncoder supports the following rate control options:

- **Constant Rate Factor (CRF)** - CRF encoding targets a specific quality level throughout, and isn't concerned with file size. Lower CRF values will result in a higher perceived quality and bitrate
  - For high quality encodes, CRF 17-18 is generally considered a good starting point
  - If file size is more important than quality, CRF 20-23 is a good starting range
- **Average Bitrate** - Average bitrate encoding targets a specific output file size, and isn't concerned with quality. There are 2 varieties of ABR encoding that FFEncoder supports:
  - **1-Pass** - This option uses a single pass, and isn't aware of the complexities of future frames and can only be scaled based on the past. Lower quality than 2-pass, but faster
  - **2-Pass** - 2-Pass encoding uses a first pass to calculate bitrate distribution, which is then used to allocate bits more accurately on the second pass

---

## Script Parameters

FFEncoder can accept the following parameters from the command line:

### **Mandatory**

> An Asterisk <b>\*</b> denotes that the parameter is mandatory only for its given parameter set (for example, you can choose either `-CRF` or `-VideoBitrate` for rate control, but not both):

| Parameter Name   | Default | Mandatory     | Alias                    | Description                                                                                                                  | Mandatory For |
| ---------------- | ------- | ------------- | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------- | ------------- |
| **InputPath**    | N/A     | True          | **I**                    | The path to the source file, i.e. remux                                                                                      | All           |
| **OutputPath**   | N/A     | True          | **O**                    | The path of the the encoded output file                                                                                      | All           |
| **CRF**          | N/A     | <b>\*</b>True | **C**                    | Rate control parameter that targets a specific quality level. Ranges from 0.0 to 51.0. Lower values result in higher quality | Rate Control  |
| **VideoBitrate** | N/A     | <b>\*</b>True | **VBitrate**             | Rate control parameter that targets a specific bitrate. Can be used as an alternative to CRF when file size is a priority    | Rate Control  |
| **Scale**        | None    | <b>\*</b>True | **Resize**, **Resample** | Scaling library to use. Options are `scale` (ffmpeg default) and `zscale` (requires `libzimg`)                               | Resizing      |

### **Utility**

| Parameter Name     | Default | Mandatory | Alias              | Description                                                                                                                             |
| ------------------ | ------- | --------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| **Help**           | False   | False     | **H**, **?**       | Switch to display help information, including examples and parameter descriptions                                                       |
| **RemoveFiles**    | False   | False     | **Del**, **RM**    | Switch that deletes extra files generated by the script (crop file, log file, etc.). Does not delete the input, output, or report files |
| **GenerateReport** | False   | False     | **Report**, **GR** | Switch that generates a report file of the encode. Data is pulled from the log file and written in a reading friendly format            |
| **Verbose**        | False   | False     | None               | `CmdletBinding` switch to enable verbose logging - cascaded down to relevant functions for additional information. Useful for debugging |
| **ExitOnError**    | False   | False     | **Exit**           | Forcibly exit script on certain non-terminating errors that prompt for re-input. Can be used to prevent blocking during automation      |

### **Audio & Subtitles**

> See [Audio Options](https://github.com/patrickenfuego/FFEncoder/wiki/Audio-Options) and [Subtitle Options](https://github.com/patrickenfuego/FFEncoder/wiki/Subtitle-Options) for more info

| Parameter Name    | Default | Mandatory | Alias                  | Description                                                                                              |
| ----------------- | ------- | --------- | ---------------------- | -------------------------------------------------------------------------------------------------------- |
| **Audio**         | Copy    | False     | **A**                  | Audio preference for the primary stream                                                                  |
| **AudioBitrate**  | Codec   | False     | **AB**, **ABitrate**   | Specifies the bitrate for `-Audio` (primary stream). Compatible with AAC, FDK AAC, AC3, EAC3, and DTS    |
| **Stereo**        | False   | False     | **2CH**, **ST**        | Switch to downmix the first audio track to stereo                                                        |
| **Audio2**        | None    | False     | **A2**                 | Audio preference for the secondary stream                                                                |
| **AudioBitrate2** | Codec   | False     | **AB2**, **ABitrate2** | Specifies the bitrate for `-Audio2` (secondary stream). Compatible with AAC, FDK AAC, AC3, EAC3, and DTS |
| **Stereo2**       | False   | False     | **2CH2**, **ST2**      | Switch to downmix the second audio track to stereo                                                       |
| **Subtitles**     | Default | False     | **S**, **Subs**        | Subtitle passthrough preference                                                                          |

### **Video Filtering**

| Parameter Name  | Default  | Mandatory     | Alias                    | Description                                                                                                                                 |
| --------------- | -------- | ------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **Scale**       | None     | <b>\*</b>True | **Resize**, **Resample** | Scaling library to use. Options are `scale` (ffmpeg default) and `zscale` (requires libzimg). Required parameter for rescaling content      |
| **ScaleFilter** | bilinear | False         | **ScaleType**, **SF**    | Scaling filter to use. See [Rescaling Video](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#rescaling-videos) for more info |
| **Resolution**  | 1080p    | False         | **Res**, **R**           | Scaling resolution. See [Rescaling Video](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#rescaling-videos) for more info    |
| **Deinterlace** | Disabled | False         | **DI**                   | Switch to enable deinterlacing of interlaced content using yadif                                                                            |

### **Encoder Config**

| Parameter Name      | Default      | Mandatory | Alias                 | Description                                                                                                                                                                  |
| ------------------- | ------------ | --------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **TestFrames**      | 0 (Disabled) | False     | **T**, **Test**       | Integer value representing the number of test frames to encode. When `-TestStart` is not set, encoding starts at 00:01:30 so that title screens are skipped                  |
| **TestStart**       | Disabled     | False     | **Start**, **TS**     | Starting point for test encodes. Accepts formats `00:01:30` (sexagesimal time), `200f` (frame start), `200t` (decimal time in seconds)                                       |
| **FirstPassType**   | Default      | False     | **PassType**, **FTP** | Tuning option for two pass encoding. See [Two Pass Encoding Options](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#two-pass-encoding-options) for more info |
| **SkipDolbyVision** | False        | False     | **NoDV**, **SDV**     | Switch to disable Dolby Vision encoding, even if metadata is present                                                                                                         |
| **SkipHDR10Plus**   | False        | False     | **No10P**, **NTP**    | Switch to disable HDR10+ encoding, even if metadata is present                                                                                                               |

### **x265 Settings**

| Parameter Name           | Default    | Mandatory | Alias            | Description                                                                                                                                                              |
| ------------------------ | ---------- | --------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Preset**               | Slow       | False     | **P**            | The x265 preset to be used. Ranges from placebo (slowest) to ultrafast (fastest). See x265 documentation for more info on preset options                                 |
| **Pass**                 | 2          | False     | None             | The number of passes the encoder will perform on ABR encodes. Used with the `-VideoBitrate` parameter. Default is 2-Pass                                                 |
| **Deblock**              | -2, -2     | False     | **DBF**          | Deblock filter. The first value controls strength, and the second value controls the frequency of use                                                                    |
| **AqMode**               | 2          | False     | **AQM**          | x265 Adaptive Quantization setting. Ranges from 0 - 4. See the [x265 Docs](https://x265.readthedocs.io/en/master/cli.html) for more info on AQ Modes and how they work   |
| **AqStrength**           | 1.00       | False     | **AQS**          | Adjusts the adaptive quantization offsets for AQ. Raising AqStrength higher than 2 will drastically affect the QP offsets, and can lead to high bitrates                 |
| **PsyRd**                | 2.00       | False     | **PRD**          | Psycho-visual enhancement. Higher values of PsyRd strongly favor similar energy over blur. See x265 documentation for more info                                          |
| **PsyRdoq**              | Preset     | False     | **PRDQ**         | Psycho-visual enhancement. Favors high AC energy in the reconstructed image, but it less efficient than PsyRd. See x265 documentation for more info                      |
| **QComp**                | 0.60       | False     | **Q**            | Sets the quantizer curve compression factor, which effects the bitrate variance throughout the encode. Must be between 0.50 and 1.0                                      |
| **BFrames**              | Preset     | False     | **B**            | The number of consecutive B-Frames within a GOP. This is especially helpful for test encodes to determine the ideal number of B-Frames to use                            |
| **BIntra**               | Preset     | False     | **BINT**         | Enables the evaluation of intra modes in B slices. Has a minor impact on performance                                                                                     |
| **StrongIntraSmoothing** | 1 (on)     | False     | **SIS**          | Enable/disable strong-intra-smoothing. Accepted values are 1 (on) and 0 (off)                                                                                            |
| **FrameThreads**         | System     | False     | **FT**           | Set frame threads. More threads equate to faster encoding, but with a decrease in quality. System default is based on the number of logical CPU cores                    |
| **Subme**                | Preset     | False     | **SM**, **SPM**  | The amount of subpel motion refinement to perform. At values larger than 2, chroma residual cost is included. Has a significant performance impact                       |
| **NoiseReduction**       | 0, 0       | False     | **NR**           | Fast Noise reduction filter built into x265. The first value represents intra frames, and the second value inter frames; values range from 0-2000                        |
| **TuDepth**              | 1, 1       | False     | **TU**           | Transform Unit recursion depth. Accepted values are 1-4. First value represents intra depth, and the second value inter depth, i.e. (`tu-intra-depth`, `tu-inter-depth`) |
| **LimitTu**              | 0          | False     | **LTU**          | Early exit condition for TU depth recursion. See the [x265 Docs](https://x265.readthedocs.io/en/master/cli.html) for more info                                           |
| **Level**             | None       | False     | **Level**, **L** | Specify the encoder level for device compatibility. Default is unset, and will be chosen by x265 based on rate control. Affects `vbv` options (see below)                |
| **VBV**                  | `Level` | False     | None             | Video buffering verifier. Default is based on the encoder level (except DV, which defaults to level 5.1). Requires 2 arguments: (`vbv-buffsize`, `vbv-maxrate`)          |

### **Extra**

> See [here](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#using-the-extra-parameter-options) for examples of how to use these parameters

| Parameter Name  | Default | Mandatory | Alias  | Description                                                                                                                                   |
| --------------- | ------- | --------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **FFMpegExtra** | N/A     | False     | **FE** | Pass additional settings to ffmpeg as a generic array of single and multi-valued elements. Useful for options not covered by other parameters |
| **x265Extra**   | N/A     | False     | **XE** | Pass additional settings to the x265 encoder as a hashtable of values. Useful for options not covered by other parameters                     |
