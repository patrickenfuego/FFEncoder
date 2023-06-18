<a href="https://github.com/patrickenfuego/FFEncoder"><img src="https://img.shields.io/badge/pwsh-v7.0%2B-blue"><a/>
<a href="https://github.com/patrickenfuego/FFEncoder"><img alt="GitHub release (latest SemVer)" src="https://img.shields.io/github/v/release/patrickenfuego/FFEncoder"><a/>
<a href="https://github.com/patrickenfuego/FFEncoder"><img src="https://img.shields.io/badge/platform-win | linux | mac-eeeeee"><a/>
<a href="https://github.com/patrickenfuego/FFEncoder"><img alt="GitHub" src="https://img.shields.io/github/license/patrickenfuego/FFEncoder?color=yellow"><a/>
<a href="https://github.com/patrickenfuego/FFEncoder"><img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/patrickenfuego/FFEncoder"><a/>
<a href="https://github.com/patrickenfuego/FFEncoder"><img alt="GitHub issues" src="https://img.shields.io/github/issues-raw/patrickenfuego/FFEncoder"><a/>
<a href="https://github.com/patrickenfuego/FFEncoder"><img alt="Encoder" src="https://img.shields.io/badge/encoder-x264%20%7C%20x265-blueviolet"><a/>

# FFEncoder

FFEncoder is a cross-platform PowerShell script and module that is meant to make high definition video encoding workflows easier. FFEncoder uses [ffmpeg](https://ffmpeg.org/), [ffprobe](https://ffmpeg.org/ffprobe.html), [VapourSynth](https://www.vapoursynth.com/doc/), [Mkvtoolnix](https://mkvtoolnix.download/), the [x264 H.264 encoder](https://x264.org/en/), and the [x265 H.265 HEVC encoder](https://x265.readthedocs.io/en/master/index.html) to compress, filter, and multiplex multimedia files for streaming or archiving.

Dynamic Metadata such as Dolby Vision and/or HDR10+ is fully supported.

---

- [FFEncoder](#ffencoder)
  - [About](#about)
  - [Dependencies](#dependencies)
  - [Dependency Installation \& Setup](#dependency-installation--setup)
    - [Windows](#windows)
    - [Linux](#linux)
    - [macOS](#macos)
    - [Adding Contents to PATH](#adding-contents-to-path)
  - [Features](#features)
    - [Auto-Cropping](#auto-cropping)
    - [Automatic HDR Metadata](#automatic-hdr-metadata)
    - [Rate Control Options](#rate-control-options)
    - [VMAF Comparison](#vmaf-comparison)
    - [MKV Tag Generator](#mkv-tag-generator)
    - [Encoding Reports](#encoding-reports)
  - [Usage](#usage)
    - [Configuration Files](#configuration-files)
    - [Parameters](#parameters)
      - [Mandatory](#mandatory)
      - [Utility](#utility)
      - [Audio \& Subtitles](#audio--subtitles)
      - [Video Filtering](#video-filtering)
      - [Encoder Config](#encoder-config)
      - [Universal Encoder Settings](#universal-encoder-settings)
      - [x265 Only Settings](#x265-only-settings)
      - [Extra](#extra)
  - [Acknowledgements](#acknowledgements)
    - [Special Mention](#special-mention)

---

## About

FFEncoder is a simple script that allows you to pass dynamic parameters to ffmpeg without needing to modify complicated CLI arguments for each source. As much as I love the ffmpeg suite, it can be complicated to learn and use; the syntax is extensive, and many of the arguments are not easy to remember unless you use them often. The goal of FFEncoder is to take common encoding workflows and make them easier, while continuing to leverage the power and flexibility of the ffmpeg tool chain.

Capability can be further expanded with the [VapourSynth](https://www.vapoursynth.com/) frameserver. FFEncoder fully supports audio, subtitle, and chapter options and will mux the streams together for you after the encode finishes. Other than video filtering options, every parameter available works with VapourSynth scripts.

Check out the [wiki](https://github.com/patrickenfuego/FFEncoder/wiki) for additional information.

---

## Dependencies

> For Windows users, PowerShell 7.x is a supplemental installation and will will be installed alongside PowerShell 5.1

> **NOTE**: PowerShell 7.3 completely changed the way string arguments are parsed with third party executables. I have updated the code to support this, and it should be backward compatible to version 7.0.0. If issues are found, please let me know

- ffmpeg / ffprobe
- PowerShell v. 7.0 or newer
- Mkvtoolnix (optional, but highly recommended)
- VapourSynth (optional)
- Dolby Encoding Engine (DEE) (optional)

For users with PowerShell 7.2 or newer, the script uses ANSI output in certain scenarios to enhance the console experience.

---

## Dependency Installation & Setup

<details>
<summary>Expand</summary>

> You can compile ffmpeg manually from source on all platforms, which allows you to select additional libraries (like Fraunhofer's libfdk AAC encoder). Some features of this script are unavailable unless these libraries are included. For more information, see [here](https://trac.ffmpeg.org/wiki/CompilationGuide).

### Windows

To download ffmpeg, navigate to the [ffmpeg downloads page](https://ffmpeg.org/download.html#build-windows) and install one of the prebuilt Windows exe packages. I recommend the builds provided by Gyan.

To install the latest version of PowerShell 7, follow the instructions provided by Microsoft [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7.1).

### Linux

You can install ffmpeg using your distro's package manager (apt/yum/pacman/zypper):

```shell
apt install ffmpeg
```

To install PowerShell 7, see Microsoft's instructions for your distribution [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1).

### macOS

The easiest way to install ffmpeg and PowerShell 7 is through the [Homebrew](https://brew.sh/) package manager:

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

### Adding Contents to PATH

The following binaries are expected to be available via system PATH in order for the script to work properly:

- ffmpeg
- ffprobe
- x265 (Dolby Vision Only)
- mkvextract, mkvmerge, mkvpropedit (optional, but recommended)
  - These should be added to PATH automatically when you install MkvToolNix
- Dolby Encoding Engine, AKA dee (Optional)

Adding contents to PATH is relatively straightforward and platform dependent. Below are some examples of how you can add software to your system PATH:

```powershell
# Whatever the path is to your ffmpeg install
$ffmpeg = 'C:\Users\SomeUser\Software\ffmpeg.exe'
$ffprobe = 'C:\Users\SomeUser\Software\ffprobe.exe'
$newPath = $env:PATH + ";$ffmpeg;$ffprobe"
[Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
# Now close and reopen PowerShell to update
```

Here is a quick example using bash/zsh on Linux/macOS:

```bash
# Set this equal to wherever ffmpeg is
ffmpeg="/home/someuser/software/ffmpeg"
# If you're using zsh (mac default), replace .bashrc with .zshrc
echo "export PATH=${ffmpeg}:${PATH}" >> ~/.bashrc
# Source the file to update
source ~/.bashrc
```

</details>

---

## Features

### Auto-Cropping

> **NOTE**: FFEncoder uses modulus 2 rounding to detect black borders. I've found this to be the most consistent choice for the majority content. If you do not want the script to auto-crop your video, you may pass **override crop values** via the `-FFMpegExtra` parameter (see [here](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#overriding-crop-arguments) for more info)

FFEncoder will auto-crop your video, and works similarly to programs like [Handbrake](https://handbrake.fr/) with more emphasis on accuracy. The script analyzes up to 6 separate segments of the source simultaneously, collects the output, and saves it to a file which is used to determine cropping values for encoding.

---

### Automatic HDR Metadata

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
  - **WARNING**: Depending on the source, the metadata ordering may be incorrect after extraction. Evaluate the generated JSON file manually and use the `-HDR10PlusSkipReorder` parameter if necessary to correct this
    - Read [the author's documentation](https://github.com/quietvoid/hdr10plus_tool) to learn why this parameter might be required and when to use it
- Dolby Vision Metadata
  - Automatically edits the generated RPU file to ensure the metadata is accurate
  - Requires `x265` (mods are fine) to be available via PATH because ffmpeg still doesn't handle RPU files correctly, even in version 5. If there is more than one `x265*` option in PATH, the first option returned is selected
  - Currently, only profile 8.1 is supported due it it's backwards compatibility with HDR10
  - It is recommended to have `mkvmerge`/`mkvextract` available. The script will multiplex tracks back together after encoding

---

### Rate Control Options

FFEncoder supports the following rate control options:

- **Constant Rate Factor (CRF)** - CRF encoding targets a specific quality level throughout, and isn't concerned with file size. Lower CRF values will result in a higher perceived quality and bitrate. For those familiar with Handbrake, this is essentially the same as `RF`
  - For high quality encodes, CRF 17-19 is generally considered a good starting range.
  - If file size is more important than quality, CRF 20-23 is a good starting range
- **Average Bitrate** (<u>Not</u> **Adaptive Bitrate**) - This is also sometimes referred to as Variable Constrained Bitrate encoding. Average bitrate encoding targets a specific output file size, and isn't concerned with quality. There are 2 varieties of ABR encoding that FFEncoder supports:
  - **1-Pass** - This option uses a single pass, and isn't aware of the complexities of future frames and can only be scaled based on the past. Lower quality than 2-pass, but faster
  - **2-Pass** - 2-Pass encoding uses a first pass to calculate bitrate distribution, which is then used to allocate bits more accurately on the second pass
- **Constant QP** - Forces a constant quantization parameter value throughout the entire encode in the form of an integer value (0 - 51). This is useful for testing as well as comparing the efficacy of encoders
  - **NOTE:** Forcing a constant QP will generally result in poor compression efficiency, and thus it is <u>**not**</u> recommended for general use (unless you know what you're doing)

---

### VMAF Comparison

The script can compare two files using Netflix's [Video Multi-Method Assessment Fusion (VMAF)](https://github.com/Netflix/vmaf) as a quality measurement.

The machine Learning model files are already provided, and Frames-Per-Second (FPS), resolution/cropping, and scaling are handled automatically; `libvmaf` requires that these parameters be identical before it will run.

Additionally, you may add `SSIM` and `PSNR` measurements as well during the same VMAF run - see [the wiki](https://github.com/patrickenfuego/FFEncoder/wiki/Quality-Assessment#introduction) for full details.

---

### MKV Tag Generator

If the selected output format is Matroska (MKV), you can use the parameter `-GenerateMKVTagFile` (or its alias, `-CreateTagFile`) to dynamically pull down metadata from TMDB, create a valid XML file, and multiplex it into the output file. This allows you to add useful metadata to your container for things like Plex and Emby to detect, or add other cool properties like Directors, Writers, and Actors for your own reference; any parameter that is available via the TMDB API can be added to your container.

To use this parameter, you will need a valid TMDB API key. See [the wiki](https://github.com/patrickenfuego/FFEncoder/wiki/MKV-Tag-Generator) for more information.

---

### Encoding Reports

![image](https://github.com/patrickenfuego/FFEncoder/assets/47511320/ef75c064-0ff7-47dc-8335-a044402d21ef)

If you're at all like me, you want to keep a record of each encode you perform for reference, comparison, or posterity. However, the ffmpeg/x265 logs are difficult to parse visually and take up a lot of disk space when saved.

FFEncoder can generate a human-readable encoding report from these hefty logs with two different formatting options:

- **HTML** - Responsive HTML report using data extracted from the log file. Some values are calculated by the script dynamically (see below).
- **text** - Text-based report extracted from the log file, formatted, and saved with a `.rep` extension for easy identification and sorting.

Reports include the following statistics:

- The start and end date/time, formatted for your locality
- Total encoding time in the form `days, hours, minutes, seconds`
- Encoding statistics
  - Encoder used
  - Total frames (if used for a test encode, the number of test frames is used instead)
  - Frames per second (FPS)
  - Final bitrate (in Mb/s)
  - Average QP
    - <u>**x264 NOTE**</u>: *x264 does not provide this statistic by default, so the script performs a weighted average calculation based on the number and average QP of each frame type. While not perfect, it's very close when compared to how x265 calculates this value.*
      - *x264's Average QP is only calculated in **HTML** reports*
- Raw encoding summary (extracted from the log)
  - If a 2-pass encode is used, statistics for both passes will be included in the summary  

Report formats are standardized across encoders to give a similar look and feel.

Reports can be generated using the `-GenerateReport` switch flag and the format type can be specified using thr `-ReportFormat` parameter. If no format is specified, `html` is the default. Report files are saved within the input file's parent directory.

If you always wish to generate a report, you can set `GenerateReport=True` in the `script.ini` configuration file.

---

## Usage

### Configuration Files

Three configuration files, `ffmpeg.ini`, `encoder.ini`, and `script.ini`, are included and can be leveraged to set frequently used options. These files are located in the `config` directory and are loaded each time the script runs.

See [the wiki](https://github.com/patrickenfuego/FFEncoder/wiki/Configuration-Files) for more information.

### Parameters

FFEncoder can accept the following parameters from the command line:

#### Mandatory

> An Asterisk <b>\*</b> denotes that the parameter is mandatory only for its given parameter set (for example, you can choose either `-CRF` or `-VideoBitrate` for rate control, but not both):

| Parameter Name   | Default | Mandatory     | Alias                            | Description                                                                                                                                          | Mandatory For |
| ---------------- | ------- | ------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| **InputPath**    | N/A     | True          | **I**, **Source**, **Reference** | The path to the source file, i.e. remux. Also acts as the reference path for VMAF comparisons                                                        | All           |
| **OutputPath**   | N/A     | True          | **O**, **Encode**, **Distorted** | The path of the the encoded output file, or the encoded (distorted) file path during VMAF comparisons                                                | All           |
| **CRF**          | N/A     | <b>\*</b>True | **C**                            | Rate control parameter that targets a specific quality level. Ranges from 0.0 to 51.0. Lower values result in higher quality                         | Rate Control  |
| **ConstantQP**   | N/A     | <b>\*</b>True | **QP**                           | Constant quantizer rate control mode. Forces a consistent QP throughout the encode. Generally not recommended outside of testing.                    | Rate Control  |
| **VideoBitrate** | N/A     | <b>\*</b>True | **VBitrate**                     | Rate control parameter that targets a specific bitrate. Can be used as an alternative to CRF when file size is a priority                            | Rate Control  |
| **ScaleKernel**  | None    | <b>\*</b>True | **ResizeKernel**                 | Scaling/resizing filter to use. See [Rescaling Video](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#rescaling-videos) for more info | Scaling       |
| **Unsharp**      | None    | <b>\*</b>True | **U**                            | Enable unsharp filter and set search range, in the form `<luma\|chroma\|yuv>_<small\|medium\|large>` or `custom=<filter>`                            | Sharpen/Blur  |
| **CompareVMAF**  | N/A     | <b>\*</b>True | None                             | Flag to enable a VMAF comparison on two video files                                                                                                  | VMAF          |

#### Utility

| Parameter Name         | Default | Mandatory | Alias              | Description                                                                                                                                         |
| ---------------------- | ------- | --------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Help**               | False   | False     | **H**, **?**       | Switch to display help information, including examples and parameter descriptions                                                                   |
| **RemoveFiles**        | False   | False     | **Del**, **RM**    | Switch that deletes extra files generated by the script (crop file, log file, etc.). Does not delete the input, output, or report file (if created) |
| **GenerateReport**     | False   | False     | **Report**, **GR** | Switch that generates a report file of the encode. Data is pulled from the log file and written in a reading friendly format                        |
| **ReportType**         | html    | False     | **ReportFormat**   | Specify the report format. Options are `html` and `text`.                                                                                           |
| **GenerateMKVTagFile** | False   | False     | **CreateTagFile**  | Generates an MKV tag file using the TMDB API (key required). See the [wiki](https://github.com/patrickenfuego/FFEncoder/wiki/MKV-Tag-Generator)     |
| **Verbose**            | False   | False     | None               | `CmdletBinding` switch to enable verbose logging - cascaded down to relevant functions for additional information. Useful for debugging             |
| **ExitOnError**        | False   | False     | **Exit**           | Switch that forcibly exits the script on certain non-terminating errors that prompt for re-input. Can be used to prevent blocking during automation |
| **EnablePSNR**         | False   | False     | **PSNR**           | Enables an additional Peak Signal-to-Noise (PSNR) measurement during VMAF comparisons                                                               |
| **EnableSSIM**         | False   | False     | **SSIM**           | Specify the resizing kernel used for upscaling/downscaling encodes for comparison                                                                   |
| **VMAFResizeKernel**   | BiCubic | False     | **VMAFKernel**     | Enables an additional Structural Similarity Index (SSIM) measurement during VMAF comparisons                                                        |
| **DisableProgress**    | False   | False     | **NoProgressBar**  | Switch to disable the progress bar during encoding                                                                                                  |

#### Audio & Subtitles

> See [Audio Options](https://github.com/patrickenfuego/FFEncoder/wiki/Audio-Options) and [Subtitle Options](https://github.com/patrickenfuego/FFEncoder/wiki/Subtitle-Options) in the wiki for more info

> Using deew requires some initial configuration before it will work properly. See [the wiki](https://github.com/patrickenfuego/FFEncoder/wiki/Audio-Options#using-the-dee-encoding-options) for more info

| Parameter Name    | Default | Mandatory | Alias                  | Description                                                                                                         |
| ----------------- | ------- | --------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Audio**         | Copy    | False     | **A**                  | Audio preference for the primary stream                                                                             |
| **AudioBitrate**  | Codec   | False     | **AB**, **ABitrate**   | Specifies the bitrate for `-Audio` (primary stream). Compatible with Dolby DEE, AAC, FDK AAC, AC3, EAC3, and DTS    |
| **Stereo**        | False   | False     | **2CH**, **ST**        | Switch to downmix the first audio track to stereo                                                                   |
| **Audio2**        | None    | False     | **A2**                 | Audio preference for the secondary stream                                                                           |
| **AudioBitrate2** | Codec   | False     | **AB2**, **ABitrate2** | Specifies the bitrate for `-Audio2` (secondary stream). Compatible with Dolby DEE, AAC, FDK AAC, AC3, EAC3, and DTS |
| **Stereo2**       | False   | False     | **2CH2**, **ST2**      | Switch to downmix the second audio track to stereo                                                                  |
| **Subtitles**     | Default | False     | **S**, **Subs**        | Subtitle passthrough preference                                                                                     |

#### Video Filtering

> See the Mandatory section above for parameters needed to enable certain filters

| Parameter Name      | Default          | Mandatory | Alias                 | Description                                                                                                                                          |
| ------------------- | ---------------- | --------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Deinterlace**     | Disabled         | False     | **DI**                | Switch to enable deinterlacing of interlaced content using yadif                                                                                     |
| **NLMeans**         | Disabled         | False     | **NL**                | High quality de-noising filter. Accepts a hashtable containing 5 values. See [here](https://ffmpeg.org/ffmpeg-filters.html#nlmeans-1) for more info  |
| **Scale**           | bilinear         | False     | **ScaleType**, **SF** | Scaling/resizing filter to use. See [Rescaling Video](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#rescaling-videos) for more info |
| **Resolution**      | Source Dependent | False     | **Res**, **R**        | Scaling resolution. See [Rescaling Video](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#rescaling-videos) for more info             |
| **UnsharpStrength** | luma_mild        | False     | **UStrength**         | Specify the unsharp filters strength, in the form `<sharpen\|blur>_<mild\|medium\|strong>`                                                           |

#### Encoder Config

| Parameter Name           | Default      | Mandatory | Alias                 | Description                                                                                                                                                                  |
| ------------------------ | ------------ | --------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Encoder**              | x265         | False     | **Enc**               | Specifies which encoder to use - x264 or x265                                                                                                                                |
| **FirstPassType**        | Default      | False     | **PassType**, **FTP** | Tuning option for two pass encoding. See [Two Pass Encoding Options](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#two-pass-encoding-options) for more info |
| **SkipDolbyVision**      | False        | False     | **NoDV**, **SDV**     | Switch to disable Dolby Vision encoding, even if metadata is present                                                                                                         |
| **DolbyVisionMode**      | 8.1          | False     | **DoViMode**          | Specify the DoVi RPU processing mode. Options are 8.1, 8.4, & 8.1m (retains FEL mapping if present, but requires additional processing in frameserver to work properly)      |
| **SkipHDR10Plus**        | False        | False     | **No10P**, **NTP**    | Switch to disable HDR10+ encoding, even if metadata is present                                                                                                               |
| **HDR10PlusSkipReorder** | False        | False     | **SkipReorder**       | Switch to correct improper HDR10+ metadata ordering on some sources. **You must verify yourself if this is required or not**                                                 |
| **TestFrames**           | 0 (Disabled) | False     | **T**, **Test**       | Integer value representing the number of test frames to encode. When `-TestStart` is not set, encoding starts at 00:01:30 so that title screens are skipped                  |
| **TestStart**            | Disabled     | False     | **Start**, **TS**     | Starting point for test encodes. Accepts formats `00:01:30` (sexagesimal time), `200f` (frame start), `200t` (decimal time in seconds)                                       |
| **VapourSynthScript**    | Disabled     | False     | **VSScript**, **VPY** | Path to VapourSynth script. Video filtering parameters are ignored when enabled, and must be done in the vpy script                                                          |

#### Universal Encoder Settings

> **NOTE**: *Encoder* means the default is specific to the encoder used. *System* is based on system hardware

| Parameter Name     | Default     | Mandatory | Alias                  | Description                                                                                                                                                            |
| ------------------ | ----------- | --------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **AqMode**         | 2           | False     | **AQM**                | x265 Adaptive Quantization setting. Ranges from 0 - 4. See the [x265 Docs](https://x265.readthedocs.io/en/master/cli.html) for more info on AQ Modes and how they work |
| **AqStrength**     | 1.00        | False     | **AQS**                | Adjusts the adaptive quantization offsets for AQ. Raising AqStrength higher than 2 will drastically affect the QP offsets, and can lead to high bitrates               |
| **Deblock**        | -2, -2      | False     | **DBF**                | Deblock filter. The first value controls strength, and the second value controls threshold. Passed as an array in the form (alpha, beta)                               |
| **BFrames**        | Preset      | False     | **B**                  | The number of consecutive B-Frames within a GOP. This is especially helpful for test encodes to determine the ideal number of B-Frames to use                          |
| **Level**          | None        | False     | **Level**, **L**       | Specify the encoder level for device compatibility. Default is unset, and will be chosen by the encoder based on rate control. Affects `VBV` options (see below)       |
| **Merange**        | Preset      | False     | **MR**                 | Sets the motion estimation search range. Higher values result in a better motion vector search during inter-frame prediction                                           |
| **NoiseReduction** | Encoder     | False     | **NR**                 | Fast Noise reduction filter. For x265, the first value represents intra frames, and the second value inter frames; values range from 0-2000                            |
| **Pass**           | 2           | False     | None                   | The number of passes the encoder will perform on ABR encodes. Used with the `-VideoBitrate` parameter. Default is 2-Pass                                               |
| **Preset**         | Slow        | False     | **P**                  | The x265 preset to be used. Ranges from placebo (slowest) to ultrafast (fastest). See x265 documentation for more info on preset options                               |
| **PsyRd**          | Encoder     | False     | **PsyRDO**             | Psycho-visual enhancement. Strongly favor similar energy over blur. For x264, you can set `psy-RDO` & `psy-trellis` (i.e. `1.00,0.04`) or `psyRDO` only                |
| **PsyRdoq**        | Preset      | False     | **PsyTrellis**         | Psycho-visual enhancement. Favors high AC energy in the reconstructed image. For x264, this can be used to set `psy-trellis` separately from `psy-RDO`                 |
| **QComp**          | 0.60        | False     | **Q**                  | Sets the quantizer curve compression factor, which effects the bitrate variance throughout the encode. x265: Must be between 0.50 and 1.0. x264: Between 0 and 1       |
| **RCLookahead**    | Preset      | False     | **RCL**, **Lookahead** | Sets the rate control lookahead option. Larger values use more memory, but can improve compression efficiency                                                          |
| **Ref**            | Preset      | False     | None                   | Sets the number of reference frames to use. Default value is based on the encoder preset. For x264, this might affect hardware compatibility                           |
| **Subme**          | Preset      | False     | **Subpel**, **SPM**    | The amount of subpel motion refinement to perform. At values larger than 2, chroma residual cost is included. Has a significant performance impact                     |
| **Threads**        | System      | False     | **FrameThreads**       | Set the number of threads. More threads equate to faster encoding. System default is based on the number of logical CPU cores                                          |
| **Tree**           | 1 (Enabled) | False     | **CUTree**, **MBTree** | Enable or disable encoder-specific lowres motion vector lookahead algorithm. 1 is enabled, 0 is disabled. Best disabled for noisy content                              |
| **VBV**            | `Level`     | False     | None                   | Video buffering verifier. Default is based on the encoder level (except DoVi, which defaults to level 5.1). Requires 2 arguments: (`vbv-bufsize`, `vbv-maxrate`)       |

#### x265 Only Settings

| Parameter Name           | Default | Mandatory | Alias    | Description                                                                                                                                                              |
| ------------------------ | ------- | --------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **BIntra**               | Preset  | False     | **BINT** | Enables the evaluation of intra modes in B slices. Has a minor impact on performance                                                                                     |
| **LimitTU**              | 0       | False     | **LTU**  | Limits the TU recursion depth based on the value passed. Acceptable values are 0 - 4. Settings are not linear, and have different impacts                                |
| **TuDepth**              | 1, 1    | False     | **TU**   | Transform Unit recursion depth. Accepted values are 1-4. First value represents intra depth, and the second value inter depth, i.e. (`tu-intra-depth`, `tu-inter-depth`) |
| **StrongIntraSmoothing** | 1 (on)  | False     | **SIS**  | Enable/disable strong-intra-smoothing. Accepted values are 1 (on) and 0 (off)                                                                                            |

#### Extra

> See [here](https://github.com/patrickenfuego/FFEncoder/wiki/Video-Options#using-the-extra-parameter-options) for examples of how to use these parameters

| Parameter Name   | Default | Mandatory | Alias  | Description                                                                                                                                   |
| ---------------- | ------- | --------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **FFMpegExtra**  | N/A     | False     | **FE** | Pass additional settings to ffmpeg as a generic array of single and multi-valued elements. Useful for options not covered by other parameters |
| **EncoderExtra** | N/A     | False     | **XE** | Pass additional settings to the specified encoder as a hashtable of values. Useful for options not covered by other parameters                |

---

## Acknowledgements

This section contains acknowledgements for the authors of tools distributed with this project. All credit goes to them!

- [dovi_tool](https://github.com/quietvoid/dovi_tool) - Developed by **quietvoid**
- [hdr10plus_tool](https://github.com/quietvoid/hdr10plus_tool) - Developed by **quietvoid**
- [deew](https://github.com/pcroland/deew) - While this project contains a modified, custom compiled version of `deew`, the original project was developed by **pcroland**
- [Get-MediaInfo](https://github.com/stax76/Get-MediaInfo) - A fast and reliable PowerShell module for reading audio/video/subtitle metadata from multimedia files. Developed by **stax76**

### Special Mention

Not distributed with the project, although used frequently in various pieces of the automation for those who have it installed. An invaluable tool for any video enthusiast (consider contributing to their development!):

- [MkvToolNix](https://mkvtoolnix.download/index.html) - Developed by **Mortiz Bunkus**
