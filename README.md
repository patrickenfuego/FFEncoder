- [FFEncoder](#ffencoder)
  - [About](#about)
  - [Auto-Cropping](#auto-cropping)
  - [Automatic HDR Metadata](#automatic-hdr-metadata)
  - [Script Parameters](#script-parameters)
  - [Hard Coded Parameters](#hard-coded-parameters)
    - [Exclusive to 4K UHD Content](#exclusive-to-4k-uhd-content)
    - [Exclusive to SDR Content 1080p and Below](#exclusive-to-sdr-content-1080p-and-below)
  - [Audio Options](#audio-options)
    - [Using the libfdk_aac Encoder](#using-the-libfdk_aac-encoder)
    - [Downmixing Multi-Channel Audio to Stereo](#downmixing-multi-channel-audio-to-stereo)
  - [Subtitles](#subtitles)
  - [Requirements](#requirements)
    - [Windows](#windows)
    - [Linux](#linux)
    - [MacOS](#macos)

&nbsp;

# FFEncoder

FFEncoder is a cross-platform PowerShell script that is meant to make high definition video encoding easier. FFEncoder uses [ffmpeg](https://ffmpeg.org/), [ffprobe](https://ffmpeg.org/ffprobe.html), and the [x265 HEVC encoder](https://x265.readthedocs.io/en/master/index.html) to compress video files for streaming or archiving.

&nbsp;

## About

FFEncoder is a simple script that allows you to pass dynamic parameters to ffmpeg without needing to modify things manually for each run. As much as I love ffmpeg/ffprobe, they can be complicated tools to use; the syntax is complex, and some of their commands are not easy to remember unless you use them often. The goal of FFEncoder is to take common encoding workflows and make them easier, while continuing to leverage the power and flexibility of the ffmpeg tool chain.

&nbsp;

## Auto-Cropping

FFEncoder will auto-crop your video, and works similarly to programs like Handbrake. The script uses ffmpeg's `cropdetect` argument to analyze 3 separate 8 minute segments of the source simultaneously. The collected output of each instance is then saved to a crop file which is used to determine the cropping width and height for encoding.

&nbsp;

## Automatic HDR Metadata

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

FFEncoder can accept the following parameters from the command line:

> An Asterisk <b>\*</b> denotes that the parameter is required only for its given parameter set (for example, you can choose either CRF or VideBitrate for rate control, but not both):

| Parameter Name     | Default         | Mandatory     | Alias                  | Description                                                                                                                                               |
| ------------------ | --------------- | ------------- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Test**           | False           | False         | **T**                  | Switch to enable a test run. Encodes only 1000 frames starting around the 1 minute mark                                                                   |
| **Help**           | False           | <b>\*</b>True | **H**, **/?**, **?**   | Switch to display help information                                                                                                                        |
| **InputPath**      | None            | True          | **I**                  | The path of the source file                                                                                                                               |
| **Audio**          | copy (stream 0) | False         | **A**                  | Audio preference for the 1st audio stream in the output file. See [Audio Options](#audio-options)                                                         |
| **AudioBitrate**   | None            | False         | **AB**, **ABitrate**   | Parameter to specify bitrate for the chosen audio codec (primary stream). Compatible with AAC, AC3, EAC3, and DTS. See [Audio Options](#audio-options)    |
| **Stereo**         | False           | False         | **2CH**, **ST**        | Switch to downmix the first audio track to stereo. See [Audio Options](#audio-options)                                                                    |
| **Audio2**         | none (skip)     | False         | **A2**                 | Audio preference for a 2nd audio stream in the output file. See [Audio Options](#audio-options)                                                           |
| **AudioBitrate2**  | None            | False         | **AB2**, **ABitrate2** | Parameter to specify bitrate for the chosen audio codec (2nd stream). Compatible with AAC, AC3, EAC3, and DTS. See [Audio Options](#audio-options)        |
| **Stereo2**        | False           | False         | **2CH2**, **ST2**      | Switch to downmix the second audio track to stereo. See [Audio Options](#audio-options)                                                                   |
| **Subtitles**      | Default (first) | False         | **S**                  | Subtitle passthrough preference. See the [Subtitles](#subtitles) section                                                                                  |
| **Preset**         | slow            | False         | **P**                  | The x265 preset to be used. Ranges from placebo (slowest) to ultrafast (fastest)                                                                          |
| **CRF**            | None            | <b>\*</b>True | **C**                  | Constant rate factor rate control setting. Ranges from 0.0 to 51.0. A lower value will result in a higher overall bitrate                                 |
| **VideoBitrate**   | None            | <b>\*</b>True | **Vbitrate**           | Constant bitrate rate control setting. This can be used as an alternative to CRF rate control, and will force the bitrate to the approximate value passed |
| **Pass**           | 2               | false         | **P**                  | The number of passes the encoder will perform. Used with the `-VideoBitrate` parameter for ABR encodes. Default is 2-Pass                                 |
| **Deblock**        | -2, -2          | False         | **DBF**                | Deblock filter. The first value controls the strength, and the second value controls the frequency of use                                                 |
| **AqMode**         | 2               | False         | **AQM**                | x265 AQ mode setting. Ranges from 0 - 4. See x265 documentation for more info on AQ Modes and how they work                                               |
| **AqStrength**     | 1.00            | False         | **AQS**                | Adjusts the adaptive quantization offsets for AQ. Raising AqStrength higher than 2 will drastically affect the QP offsets, and can lead to high bitrates  |
| **PsyRd**          | 2.00            | False         | **PRD**                | Psycho-visual enhancement. Higher values of PsyRd strongly favor similar energy over blur. See x265 documentation for more info                           |
| **PsyRdoq**        | 1.00            | False         | **PRDQ**               | Psycho-visual enhancement. Favors high AC energy in the reconstructed image, but it less efficient than PsyRd. See x265 documentation for more info       |
| **QComp**          | 0.60            | False         | **Q**                  | Sets the quantizer curve compression factor, which effects the bitrate variance throughout the encode. Must be between 0.50 and 1.0                       |
| **BFrames**        | 4               | False         | **B**                  | The number of B-frames to be used within a GOP. This is especially helpful for test encodes to determine the ideal number of B-frames to use              |
| **NoiseReduction** | 0, 0            | False         | **NR**                 | Noise reduction filter. The first value represents intra frames, and the second value inter frames; values range from 0-2000. Useful for grainy sources   |
| **OutputPath**     | None            | True          | **O**                  | The path of the encoded output file                                                                                                                       |

&nbsp;

## Hard Coded Parameters

Video encoding is a subjective process, and I have my own personal preferences. The following parameters are hard coded, but can be changed easily:

- `subme=4` - This is the default for the veryslow preset, and I find that it gives better high motion clarity without too much of a performance hit. I plan to add a parameter for this sometime soon
- `no-sao` - I really hate the way sao looks, so it's disabled along with `selective-sao`. There's a reason it has earned the moniker "smooth all objects", and it makes everything look too waxy in my opinion
- `rc-lookahead=48` - People are all over the board with this, but I have found 48 (2 \* 24 fps, or effectively, 2 \* fps) to be a number with good gains and no diminishing returns. This is recommended by many experienced folks at the [doom9 forum](https://forum.doom9.org/showthread.php?t=175993)
- `keyint-120` - This is personal preference. I like to spend a few extra bits to insert more I-frames into a GOP, which helps with seeking (fast-forwarding, rewinding, random seeking) through the video
- `no-open-gop` - The UHD BD specification recommends that closed GOPs be used. in general, closed GOPs are preferred for streaming content. x264 had closed GOPs by default. For more insight, listen to what [Ben Waggoner](https://streaminglearningcenter.com/articles/open-and-closed-gops-all-you-need-to-know.html) has to say on the topic
- `b-intra` - I recently turned this on for testing, and have been happy enough with it to leave it on. Has a very mild impact on performance
- `frame-threads=2` - It is known that more frame threads degrade overall quality (additional reading can be found [here](https://forum.doom9.org/showthread.php?t=176197&page=3)). 2 frame threads is a nice compromise for most systems

### Exclusive to 4K UHD Content

- `level-idc=5.1`, `high tier=1` - I have found this to be ideal for 4K content as `Main 10@L5@Main` only allows for a maximum bitrate of 25 mb/s (and 4K content sometimes exceeds this, especially if there is a lot of grain)

### Exclusive to SDR Content 1080p and Below

- `merange` - The default value of 57 is a bit much for 1080p content, and it slows the encode with no noticeable gain. Value is set to 44. For 720p content, merange could lowered even more

&nbsp;

## Audio Options

FFEncoder supports the mapping/transcoding of 2 distinct audio streams to the output file. For audio that is transcoded, the primary audio stream is used as it's generally lossless (TrueHD, DTS-HD MA, LPCM, etc.). **It is never recommended to transcode from one lossy codec to another**.

FFEncoder currently supports the following audio options wih the `-Audio`/`-Audio2` parameters. When selecting a named codec (like EAC3, AC3, etc.) the script will go through the following checks:

1.  If either of the `-AudioBitrate` parameters are selected, the corresponding stream will be transcoded to the selected codec, regardless if an existing stream is present
2.  If the `-AudioBitrate` parameters are not present, the script will search the input file for a matching stream and stream copy it to the output file if found
3.  If no bitrate is specified and no existing stream is found, then the script will transcode to the selected codec at the default bitrates listed below:

**NOTE:** To copy Dolby Atmos streams, you **must** be using the latest ffmpeg build **or the script will fail**

| Type         | Values           | Default        | Description                                                                                                                            |
| ------------ | ---------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Copy**     | `copy`, `c`      | N/A            | Passes through the primary audio stream without re-encoding                                                                            |
| **Copy All** | `copyall`, `ca`  | N/A            | Passes through all audio streams from the input to the output without re-encoding                                                      |
| **AAC**      | `aac`            | 512 kb/s       | Converts the primary audio stream to AAC using ffmpeg's native CBR encoder. Compatible with the `-AudioBitrate` parameter              |
| **FDK AAC**  | `fdkaac`, `faac` | Variable (VBR) | Converts the primary audio stream to AAC using libfdk_aac. Compatible with the `-AudioBitrate` parameter. See note below for more info |
| **AC3**      | `ac3`, `dd`      | 640 kb/s       | Dolby Digital. Compatible with the `-AudioBitrate` parameter                                                                           |
| **E-AC3**    | `eac3`           | 448 kb/s       | Dolby Digital Plus. Compatible with the `-AudioBitrate` parameter                                                                      |
| **DTS**      | `dts`            | Variable (VBR) | DTS Core audio. **Warning**: ffmpeg's DTS encoder is "experimental". Compatible with the `-AudioBitrate` parameter                     |
| **FLAC**     | `flac`, `f`      | Variable (VBR) | Converts the primary audio stream to FLAC lossless audio using ffmpeg's native FLAC encoder                                            |
| **Stream #** | `0-5`            | N/A            | Select an audio stream using its stream identifier in ffmpeg/ffprobe. Not compatible with the `-Stereo` parameters                     |
| **None**     | `none`, `n`      | N/A            | Removes all audio streams from the output. This is ideal for object based streams like Dolby Atmos, as it cannot currently be decoded  |

&nbsp;

### Using the libfdk_aac Encoder

FFEncoder includes support for Fraunhofer's libfdk_aac, even though it is not included in a standard ffmpeg executable. Due to a conflict with ffmpeg's LGPL, libfdk_aac cannot be distributed with any official ffmpeg binaries, but it can be included when compiling ffmpeg manually from source. For more information on compiling from source, see [Requirements](#requirements).

One of the benefits of the FDK encoder is that it supports variable bitrate (VBR). When using the `-AudioBitrate`/`-AudioBitrate2` parameters with `fdkaac`, values 1-5 are used to signal VBR. 1 = lowest quality and 5 = highest quality

### Downmixing Multi-Channel Audio to Stereo

With FFEncoder, you can downmix either of the two output streams to stereo using the `-Stereo`/`-Stereo2` parameters. The process uses an audio filter that retains the LFE (bass) track in the final mix, which is discarded when using `-ac 2` in ffmpeg directly.

When using any combination of `copy`/`c`/`copyall`/`ca` and `-Stereo`/`-Stereo2`, the script will multiplex the primary audio out of the container and encode it separately; this is because ffmpeg cannot stream copy and filter at the same time. See [here](https://stackoverflow.com/questions/53518589/how-to-use-filtering-and-stream-copy-together-with-ffmpeg) for a nice explanation. Once the primary encode finishes, the multiplexed audio file (now converted to stereo) is multiplexed back into the primary container with the other streams selected.

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

**NOTE:** You can compile ffmpeg manually from source on all platforms, which allows you to select additional libraries (such as Fraunhofer's libfdk AAC encoder). For more information, see [here](https://trac.ffmpeg.org/wiki/CompilationGuide)

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
