# FFEncoder

FFEncoder is a PowerShell script that is meant to make high definition video encoding easier. FFEncoder uses [ffmpeg](https://ffmpeg.org/) and the [x265 HEVC encoder](https://x265.readthedocs.io/en/master/index.html) to compress 4K HDR (3840x2160) video files to be used for streaming or archiving.

## About

FFEncoder is a simple script that allows you to pass dynamic parameters to ffmpeg without needing to modify things manually for each run.

FFEncoder will also auto-crop your video, and works similarly to programs like Handbrake. I found myself using Handbrake a lot for its auto-cropping magic, and decided to find a way to automate it in ffmpeg. The script uses ffmpeg's `cropdetect` argument to analyze every frame in the video, then saves the output to a file called crop.txt, and finally scans crop.txt for the maximum width and height values. These values are then used for cropping.

## Script Arguments

FFEncoder can accept the following arguments from the command line:

| Name         | Default | Mandatory           | Alias    | Description                                                                                                 |
| ------------ | ------- | ------------------- | -------- | ----------------------------------------------------------------------------------------------------------- |
| Test         | False   | False               | T        | Switches test run on. Only encodes the first 1000 frames                                                    |
| Help         | False   | True for Help only  | H, /?, ? | Switch to display help information                                                                          |
| 1080p        | False   | True for 1080p only | None     | Switch to enable 1080p and remove HDR arguments. Mandatory only for the 1080p parameter set (still testing) |
| InputPath    | None    | True                | I        | The path to the video file to be encoded                                                                    |
| Preset       | slow    | False               | P        | The x265 preset to be used. Ranges from placebo (slowest) to ultrafast (fastest)                            |
| CRF          | 16.0    | False               | None     | Constant rate factor. Ranges from 0.0 to 51.0. Lower value results in higher bitrate                        |
| Deblock      | -1,-1   | False               | DBF      | Deblock filter. The first value controls the strength, and the second value controls the frequency of use   |
| MaxLuminance | None    | True for 4K only    | MaxL     | Max master display luminance value for HDR. Mandatory only for the 2160p parameter set                      |
| MinLuminance | None    | True for 4K only    | MinL     | Min master display luminance value for HDR. Mandatory only for the 2160p parameter set                      |
| MaxCLL       | None    | True for 4K only    | None     | Max content light level value for HDR. Mandatory only for the 2160p parameter set                           |
| MinCLL       | None    | True for 4K only    | None     | Min content light level value for HDR. Mandatory only for the 2160p parameter set                           |
| OutputPath   | None    | True                | O        | The path of the encoded output file                                                                         |

## Development

The current build has been tested on Windows at 4K with HDR. I am currently working on adding support for UNIX operating systems via [PowerShell Core](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1), and plan to add 1080p support as well. I also plan on adding support for 1080p HDR and 4K SDR at some point, too.
