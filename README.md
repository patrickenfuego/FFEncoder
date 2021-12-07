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
  - [Video Options](#video-options)
    - [Two Pass Encoding Options](#two-pass-encoding-options)
    - [Rescaling Videos](#rescaling-videos)
    - [Using the Extra Parameter Options](#using-the-extra-parameter-options)
  - [Hard Coded Parameters](#hard-coded-parameters)
    - [Exclusive to 4K UHD Content](#exclusive-to-4k-uhd-content)
    - [Exclusive to SDR Content 1080p and Below](#exclusive-to-sdr-content-1080p-and-below)
  - [Audio Options](#audio-options)
    - [Using the libfdk_aac Encoder](#using-the-libfdk_aac-encoder)
    - [Using the aac_at Encoder](#using-the-aac_at-encoder)
    - [Downmixing Multi-Channel Audio to Stereo](#downmixing-multi-channel-audio-to-stereo)
  - [Subtitle Options](#subtitle-options)

---

# FFEncoder

FFEncoder is a cross-platform PowerShell script that is meant to make high definition video encoding easier. FFEncoder uses [ffmpeg](https://ffmpeg.org/), [ffprobe](https://ffmpeg.org/ffprobe.html), and the [x265 HEVC encoder](https://x265.readthedocs.io/en/master/index.html) to compress video files for streaming or archiving.

## About

FFEncoder is a simple script that allows you to pass dynamic parameters to ffmpeg without needing to modify complicated CLI arguments for each source. As much as I love the ffmpeg suite, it can be complicated to learn and use; the syntax is extensive, and many of the arguments are not easy to remember unless you use them often. The goal of FFEncoder is to take common encoding workflows and make them easier, while continuing to leverage the power and flexibility of the ffmpeg tool chain.

---

## Dependencies

- ffmpeg / ffprobe
- PowerShell Core v. 7.0 or newer

The script requires PowerShell Core 7.0 or newer on all systems as it utilizes new parallel processing features introduced in this version. Multi-threading prior to PowerShell 7 was prone to memory leaks which persuaded me to make the change.

`mkvmerge` and `mkvextract` from Mkvtoolnix are **recommended**, but not required.

> For Windows users, PowerShell Core is a supplemental installation and will will be installed alongside PowerShell 5.1

---

## Dependency Installation

> You can compile ffmpeg manually from source on all platforms, which allows you to select additional libraries (like Fraunhofer's libfdk AAC encoder). For more information, see [here](https://trac.ffmpeg.org/wiki/CompilationGuide)

### Windows

To download ffmpeg, navigate to the [ffmpeg downloads page](https://ffmpeg.org/download.html#build-windows) and install one of the prebuilt Windows exe packages. I recommend the builds provided by Gyan.

To install the latest version of PowerShell Core, follow the instructions provided by Microsoft [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7.1).

### Linux

You can install ffmpeg using your package manager of choice (apt/yum/pacman):

```shell
apt install ffmpeg
```

To install PowerShell core, see Microsoft's instructions for your distribution [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1).

### macOS

The easiest way to install ffmpeg and PowerShell core is through the [Homebrew](https://brew.sh/) package manager:

```shell
brew install ffmpeg
```

One of the other benefits of using Homebrew is that you can easily install a build that includes non-free libraries like fdk_aac:

```shell
brew install ffmpeg --with-fdk-aac
```

To install PowerShell Core, run the following command using Homebrew:

```shell
brew install --cask powershell
```

---

## Auto-Cropping

> **NOTE**: FFEncoder uses modulus 2 rounding to detect black borders. I've found this to be the most consistent choice for the majority content. If you do not want the script to auto-crop your video, you may pass **override crop values** via the `-FFMpegExtra` parameter (see [Script Parameters](#script-parameters) for more info).

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
  - Recommended values for 1080p content are between 16-24
  - Recommended values for 2160p content are between 17-26
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

### **Audio & Subtitles**

> See [Audio Options](#audio-options) and [Subtitle Options](#subtitle-options) for more info

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

| Parameter Name  | Default  | Mandatory     | Alias                    | Description                                                                                                                            |
| --------------- | -------- | ------------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Scale**       | None     | <b>\*</b>True | **Resize**, **Resample** | Scaling library to use. Options are `scale` (ffmpeg default) and `zscale` (requires libzimg). Required parameter for rescaling content |
| **ScaleFilter** | bilinear | False         | **ScaleType**, **SF**    | Scaling filter to use. See [Rescaling Video](#rescaling-video) for more info                                                           |
| **Resolution**  | 1080p    | False         | **Res**, **R**           | Scaling resolution. See [Rescaling Video](#rescaling-video) for more info                                                              |
| **Deinterlace** | Disabled | False         | **DI**                   | Switch to enable deinterlacing of interlaced content using yadif                                                                       |

### **Encoder Config**

| Parameter Name      | Default      | Mandatory | Alias                 | Description                                                                                                                                                 |
| ------------------- | ------------ | --------- | --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **TestFrames**      | 0 (Disabled) | False     | **T**, **Test**       | Integer value representing the number of test frames to encode. When `-TestStart` is not set, encoding starts at 00:01:30 so that title screens are skipped |
| **TestStart**       | Disabled     | False     | **Start**, **TS**     | Starting point for test encodes. Accepts formats `00:01:30` (sexagesimal time), `200f` (frame start), `200t` (decimal time in seconds)                      |
| **FirstPassType**   | Default      | False     | **PassType**, **FTP** | Tuning option for two pass encoding. See [Two Pass Encoding Options](#two-pass-encoding-options) for more info                                              |
| **SkipDolbyVision** | False        | False     | **NoDV**, **SDV**     | Switch to disable Dolby Vision encoding, even if metadata is present                                                                                        |
| **SkipHDR10Plus**   | False        | False     | **No10P**, **NTP**    | Switch to disable HDR10+ encoding, even if metadata is present                                                                                              |

### **x265 Settings**

| Parameter Name           | Default    | Mandatory | Alias            | Description                                                                                                                                                              |
| ------------------------ | ---------- | --------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Preset**               | Slow       | False     | **P**            | The x265 preset to be used. Ranges from placebo (slowest) to ultrafast (fastest). See x265 documentation for more info on preset options                                 |
| **Pass**                 | 2          | False     | **P**            | The number of passes the encoder will perform on ABR encodes. Used with the `-VideoBitrate` parameter. Default is 2-Pass                                                 |
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
| **LevelIDC**             | None       | False     | **Level**, **L** | Specify the encoder level for device compatibility. Default is unset, and will be chosen by x265 based on rate control. Affects `vbv` options (see below)                |
| **VBV**                  | `LevelIDC` | False     | None             | Video buffering verifier. Default is based on the encoder level (except DV, which defaults to level 5.1). Requires 2 arguments: (`vbv-buffsize`, `vbv-maxrate`)          |

### **Extra**

> See [here](#using-the-extra-parameter-options) for examples of how to use these parameters

| Parameter Name  | Default | Mandatory | Alias  | Description                                                                                                                                   |
| --------------- | ------- | --------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **FFMpegExtra** | N/A     | False     | **FE** | Pass additional settings to ffmpeg as a generic array of single and multi-valued elements. Useful for options not covered by other parameters |
| **x265Extra**   | N/A     | False     | **XE** | Pass additional settings to the x265 encoder as a hashtable of values. Useful for options not covered by other parameters                     |

## Video Options

The following sections demonstrate features, syntax, and examples on how to use some of FFEncoder's video-specific parameters:

### Two Pass Encoding Options

FFEncoder supports three options for tuning the **first pass** of a two pass encode:

| Arguments     | Affected Parameters                                                                                                                    | Description                                                                                                                                       |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Default`/`d` | None                                                                                                                                   | Uses the same settings for both passes, and is the slowest option. This is the default setting                                                    |
| `Fast`/`f`    | `rect=0`<br>`amp=0`<br>`max-merge=1`<br>`fast-intra=1`<br>`fast-intra=1`<br>`early-skip=1`<br>`rd=2`<br>`subme=2`<br>`me=0`<br>`ref=1` | This is essentially equivalent to using the `--no-slow-firstpass` parameter in x265. The following settings are modified for the first pass only: |
| `Custom`/`c`  | `rect=0`<br>`amp=0`<br>`max-merge=2`<br>`subme=2`                                                                                      | My own custom settings, meant to strike a compromise between the speed of `Fast` and quality of `Default`                                         |

### Rescaling Videos

> **NOTE**: Dithering is currently not supported with scaling, as most of the code is written to use the `Main 10` profile; however, I do plan on adding it in a future release

You can rescale (upscale/downscale) a video with FFEncoder using the three scaling-related parameters:

- `-Scale` (**required for rescaling**)
- `-ScaleFilter`
- `-Resolution`

The script currently supports three resolutions to which you can scale between: **2160p**, **1080p**, and **720p**. Rescaling retains SAR (source aspect ratio) and will use the input cropping width to determine aspect ratio (it will also work with overridden crop values passed via `-FFMpegExtra`). The available options for `-ScaleFilter` depend on the scaling library used:

| Library  | Available Options                                                                        |
| -------- | ---------------------------------------------------------------------------------------- |
| `scale`  | fast_bilinear, bilinear, bicubic, neighbor, area, bicublin, gauss, sinc, lanczos, spline |
| `zscale` | point, bilinear, bicubic, spline16, spline36, lanczos                                    |

### Using the Extra Parameter Options

> **WARNING**: The script **does not** check syntax, and assumes you know what you're doing. Be sure to test!

You can pass additional arguments not provided by the script to both ffmpeg and x265 using the `-FFMpegExtra` and `-x265Extra` parameters, respectively.

`-FFMpegExtra` accepts a generic array that can receive single and multi-valued arguments. For options that receive no argument, i.e. `stats/nostats`, pass it as a single element; otherwise, use a hashtable. For example:

```PowerShell
#Pass additional arguments to ffmpeg using an array with a hashtable and a single value
.\FFEncoder.ps1 $InputPath -CRF 18 -FFMpegExtra @{ '-t' = 20; '-stats_period' = 5 }, '-shortest' -o $OutputPath
```

`-x265Extra` accepts a hashtable of values as input, in the form of `<key = value>`. For example:

```PowerShell
#Pass additional arguments to the x265 encoder using a hashtable of values
.\FFEncoder.ps1 $InputPath -CRF 18 -x265Extra @{ 'max-merge' = 1; 'max-tu-size' = 16 } -o $OutputPath
```

---

## Hard Coded Parameters

Video encoding is a subjective process, and I have my own personal preferences. The following parameters are hard coded, but can be overridden using the `-x265Extra` parameter:

- `no-sao` - I really hate the way sao looks, so it's disabled along with `selective-sao`. There's a reason it's earned the moniker "smooth all objects", and it makes everything look too waxy in my opinion
- `rc-lookahead=48` - I have found 48 (2 \* 24 fps) to be a number with good gains and no diminishing returns. This is recommended by many at the [doom9 forums](https://forum.doom9.org/showthread.php?t=175993)
- `keyint=192` - This is personal preference. I like to spend a few extra bits to insert more I-frames into a GOP, which helps with random seeking throughout the video. The bitrate increase is trivial
- `no-open-gop` - The UHD BD specification recommends that closed GOPs be used. in general, closed GOPs are preferred for streaming content. x264 uses closed GOPs by default

### Exclusive to 4K UHD Content

- `level-idc=5.1` - Pretty much the default these days for 4K content

### Exclusive to SDR Content 1080p and Below

- `merange=44` - The default value of 57 is a bit much for 1080p content, and it slows the encode with no noticeable gain

---

## Audio Options

FFEncoder supports the mapping/transcoding of 2 distinct audio streams to the output file. For audio that is transcoded, the primary audio stream is used as it's generally lossless (TrueHD, DTS-HD MA, LPCM, etc.). **It is never recommended to transcode from one lossy codec to another**; if the primary audio stream is lossy compressed, it is best to stream copy it instead of forcing a transcode.

FFEncoder currently supports the following audio options wih the `-Audio`/`-Audio2` parameters. When selecting a named codec (like EAC3, AC3, etc.) the script will go through the following checks:

1.  If either of the `-AudioBitrate` parameters are selected, the corresponding stream will be transcoded to the selected codec, regardless if an existing stream is present in the input file
2.  If the `-AudioBitrate` parameters are not present, the script will search the input file for a matching stream and stream copy it to the output file if found
3.  If no bitrate is specified and no existing stream is found, then the script will transcode to the selected codec at the default bitrates listed below:

| Type         | Values           | Default        | Description                                                                                                                             |
| ------------ | ---------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| **Copy**     | `copy`, `c`      | N/A            | Passes through the primary audio stream without re-encoding                                                                             |
| **Copy All** | `copyall`, `ca`  | N/A            | Passes through all audio streams from the input to the output without re-encoding                                                       |
| **AAC**      | `aac`            | 512 kb/s       | Converts the primary audio stream to AAC using ffmpeg's native CBR encoder. Compatible with the `-AudioBitrate` parameters              |
| **FDK AAC**  | `fdkaac`, `faac` | Variable (VBR) | Converts the primary audio stream to AAC using libfdk_aac. Compatible with the `-AudioBitrate` parameters. See note below for more info |
| **AAC_AT**   | `aac_at`         | Variable (VBR) | Converts the primary audio stream to AAC using Apple Core Audio Toolbox (MacOS only). Compatible with the `-AudioBitrate` parameters    |
| **AC3**      | `ac3`, `dd`      | 640 kb/s       | Dolby Digital. Compatible with the `-AudioBitrate` parameters                                                                           |
| **E-AC3**    | `eac3`           | 448 kb/s       | Dolby Digital Plus. Compatible with the `-AudioBitrate` parameters                                                                      |
| **DTS**      | `dts`            | Variable (VBR) | DTS Core audio. **Warning**: ffmpeg's DTS encoder is "experimental". Compatible with the `-AudioBitrate` parameters                     |
| **FLAC**     | `flac`, `f`      | Variable (VBR) | Converts the primary audio stream to FLAC lossless audio using ffmpeg's native FLAC encoder                                             |
| **Stream #** | `0-5`            | N/A            | Select an audio stream using its stream identifier in ffmpeg/ffprobe. Not compatible with the `-Stereo` parameters                      |
| **None**     | `none`, `n`      | N/A            | No audio streams will be added to the output file                                                                                       |

---

### Using the libfdk_aac Encoder

FFEncoder includes support for Fraunhofer's libfdk_aac, even though it is not included in a standard ffmpeg executable. Due to a conflict with ffmpeg's GPL, libfdk_aac cannot be distributed with any official ffmpeg binaries, but it can be included when compiling ffmpeg manually from source. For more info, see [Dependencies](#Dependencies).

One of the benefits of the FDK encoder is that it supports variable bitrate (VBR). When using the `-AudioBitrate`/`-AudioBitrate2` parameters with `fdkaac`, **values 1-5 are used to signal VBR**. 1 = lowest quality and 5 = highest quality.

### Using the aac_at Encoder

When running FFEncoder on a Mac computer, you gain access to the AudioToolbox AAC encoder (open source port of Apple's high quality encoder) via the `aac_at` argument. AudioToolbox is, by default, a variable Bitrate (VBR) encoder, but can accept the following values using `-AudioBitrate`/`-AudioBitrate2`:

- -1 - Auto (VBR)
- 0 - Constant bitrate (CBR)
- 1 - Long-term Average bitrate (ABR)
- 2 - Constrained variable bitrate (VBR)
- 3 - Variable bitrate (VBR)

### Downmixing Multi-Channel Audio to Stereo

With FFEncoder, you can downmix either of the two output streams to stereo using the `-Stereo`/`-Stereo2` parameters. The process uses an audio filter that retains the LFE (bass) track in the final mix, which is discarded when using `-ac 2` in ffmpeg directly.

When using any combination of `copy`/`c`/`copyall`/`ca` and `-Stereo`/`-Stereo2`, the script will multiplex the primary audio stream out of the container and encode it separately; this is because ffmpeg cannot stream copy and filter at the same time. See [here](https://stackoverflow.com/questions/53518589/how-to-use-filtering-and-stream-copy-together-with-ffmpeg) for a nice explanation. Once the primary encode finishes, the external audio file (now converted to stereo) is multiplexed back into the primary container with the other streams selected.

---

## Subtitle Options

FFEncoder can copy subtitle streams from the input file to the output file using the `-Subtitles` / `s` parameter. I have not added subtitle transcoding because, frankly, ffmpeg is not the best option for this. If you need to convert subtitles from one format to the other, I recommend using [Subtitle Edit](https://www.nikse.dk/SubtitleEdit/) (Windows only).

The different parameter options are:

- `default` / `d` - Copies the default (primary) subtitle stream from the input file
- `all` / `a` - Copies all subtitle streams from the input file
- `none` / `n` - Excludes subtitles from the output entirely
- **Language** - You can also specify a language to copy, and FFEncoder will search the input for all subtitles matching that language. If the specified language isn't found, no subtitles will be copied. The following languages are supported using the language code on the right:

  | Language  | Code  |
  | --------- | ----- |
  | Chinese   | `chi` |
  | Czech     | `cze` |
  | Danish    | `dan` |
  | Dutch     | `dut` |
  | English   | `eng` |
  | Finnish   | `fin` |
  | French    | `fre` |
  | German    | `ger` |
  | Greek     | `gre` |
  | Korean    | `kor` |
  | Norwegian | `nor` |
  | Polish    | `pol` |
  | Romanian  | `rum` |
  | Russian   | `rus` |
  | Spanish   | `spa` |
  | Swedish   | `swe` |
