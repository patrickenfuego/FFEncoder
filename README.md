# FFEncoder

FFEncoder is a PowerShell script that is meant to make high definition video encoding easier. FFEncoder uses [ffmpeg](https://ffmpeg.org/) and the [x265 HEVC encoder](https://x265.readthedocs.io/en/master/index.html) to compress 4K HDR (3840x2160) video files to be used for streaming or archiving.

## About

FFEncoder is a simple script that allows you to pass dynamic parameters to ffmpeg without needing to modify things manually for each run.

FFEncoder will also auto-crop your video, and works similarly to programs like Handbrake. I found myself using Handbrake a lot for its auto-cropping magic, and decided to find a way to automate it in ffmpeg. The script uses ffmpeg's `cropdetect` argument to analyze every frame in the video, then saves the output to a file called crop.txt, and finally scans crop.txt for the maximum width and height values. These values are then used for cropping.

## Script Arguments

FFEncoder can accept the following arguments from the command line:

| Name         | Default | Mandatory           | Alias    | Description                                                                                               |
| ------------ | ------- | ------------------- | -------- | --------------------------------------------------------------------------------------------------------- |
| Test         | False   | False               | T        | Switches test run on. Only encodes the first 1000 frames                                                  |
| Help         | False   | True for Help only  | H, /?, ? | Switch to display help information                                                                        |
| 1080p        | False   | True for 1080p only | None     | Switch to enable 1080p downsampling. Mandatory only for the 1080p parameter set (still testing)           |
| InputPath    | None    | True                | I        | The path to the video file to be encoded                                                                  |
| Preset       | slow    | False               | P        | The x265 preset to be used. Ranges from placebo (slowest) to ultrafast (fastest)                          |
| CRF          | 16.0    | False               | None     | Constant rate factor. Ranges from 0.0 to 51.0. Lower value results in higher bitrate                      |
| Deblock      | -1,-1   | False               | DBF      | Deblock filter. The first value controls the strength, and the second value controls the frequency of use |
| MaxLuminance | None    | True for 4K only    | MaxL     | Max master display luminance value for HDR. Mandatory only for the 2160p parameter set                    |
| MinLuminance | None    | True for 4K only    | MinL     | Min master display luminance value for HDR. Mandatory only for the 2160p parameter set                    |
| MaxCLL       | None    | True for 4K only    | CLL      | Maximum content light level value for HDR. Mandatory only for the 2160p parameter set                     |
| MaxFAL       | None    | True for 4K only    | FAL      | Maximum frame average light level value for HDR. Mandatory only for the 2160p parameter set               |
| OutputPath   | None    | True                | O        | The path of the encoded output file                                                                       |

## Compatibility

FFEncoder is currently supported on Windows, MacOS, and Linux. Functionality for MacOS and Linux require [PowerShell Core](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1). PowerShell core can be installed using Homebrew (MacOS), apt/pacman/yum (Linux), or manually (see documentation).

the builds I have been able to confirm so far are:

- Windows 10 v. 2009
- MacOS v. 11.0.1 "Big Sur"
- Ubuntu v. 20.04 LTS

I do not plan to test on Windows 7. I do plan to test on Arch and Red Hat based distributions at some point, but I have no reason to think they would not work also. For MacOS, I would assume that anything which can run on Big Sur will work on previous versions as well.

## Development

My future plans for this script, in the order that they are likely to occur:

- 1080p HDR support. I have this feature roughly half done, so this will be next on the list.
- Add additional commonly modified parameters for x265, like:
  - `aq-mode` - FFEncoder uses 2, but for 1080p encodes, 3 is usually preferred. I will add a parameter for it when I add 1080p.
  - `aq-strength` - This can be helpful for controlling bitrate when encoding 1080p sources, so I will add a parameter for it.
  - `tier` - FFEncoder currently uses Main10 profile, level 5.1 @ high tier. For 1080p encodes, high tier isn't necessary, so I'll add a switch to disable it.
  - `subme` - My current default is 4, and this is what FFEncoder also uses. Sometimes I prefer a lower/higher value for performance reasons, so it's on the list.
  - `psy-rd` - For 4K, I usually leave it at default (2.00), but I will add a parameter for it in the future.
  - `psy-rdoq` - Like psy-rd, the default is usually fine. With sources that have a lot of grain, though, a parameter would be helpful.
  - `dhdr10` - Whenever I get a source that has Dynamic HDR, this parameter will get added.
- 2160p SDR support. This requires a mapping process that I have never done before, but I do hope to add it at some point.
- 1080p SDR support. Handbrake is still king for 1080p SDR content in my opinion, but I still may add this eventually.
- AAC Audio Conversion - I usually stick with the lossless codecs, but for some sources I prefer AAC to save space. I already have a script that does this, so it's a matter of merging it in with this code.
