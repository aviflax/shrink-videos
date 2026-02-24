# `shrink-videos`

This is a Mac CLI tool that can:

* Find all Motion JPEG videos in the user’s Photos Library
* Convert those videos into HEVC-encoded .mp4 files
  * While preserving audio+video quality and metadata


## Usage

`shrink-videos` has these options:

* `--dry-run [true|false]` — `true` means that Motion JPEG videos will be found, but not converted. Defaults to `true`.
* `--all` means that all Motion JPEG videos found; without this, only the first video found is processed
* `--skip N` — skip the first N found videos before processing. E.g. `--skip 1` processes the second video found.
* `--add` — after conversion, add the converted video to the Photos library with the original video's metadata (creation date, location, favorite status)
* `--replace` — like `--add`, but also deletes the original video (moved to Recently Deleted). Mutually exclusive with `--add`.
* `--scan` — scan all videos and report a codec distribution breakdown (count and total size per codec), sorted by total size. Does not convert anything.

### Examples

* `swift run shrink-videos --dry-run true` will find a single Motion JPEG video and output information about it
* `swift run shrink-videos --dry-run true --all` will find all Motion JPEG videos and output information about each one
* `swift run shrink-videos --dry-run false` will find a single Motion JPEG video, convert it to HEVC, and save it to `/tmp/`
* `swift run shrink-videos --dry-run false --all` will convert all Motion JPEG videos to HEVC, processing the largest first
* `swift run shrink-videos --dry-run false --all --replace` will convert all Motion JPEG videos, add them to Photos, and delete the originals
* `swift run shrink-videos --scan` will report a breakdown of all video codecs in the Photos library
