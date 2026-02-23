# Shrink Videos

This is a Mac CLI app that can:

* Find all Motion JPEG videos in the user’s Photos Library
* Convert those videos into HEVC-encoded .mp4 files
  * Without any loss of image or sound quality whatsoever
  * Without any loss of metadata whatsoever


## Usage

`shrink-videos` has these options:

* `--dry-run [true|false]` — `true` means that Motion JPEG videos will be found, but not converted. Defaults to `true`.
* `--all` means that all Motion JPEG videos found; without this, only the first video found is processed
* `--skip N` — skip the first N found videos before processing. E.g. `--skip 1` processes the second video found.
* `--add` — after conversion, add the converted video to the Photos library with the original video's metadata (creation date, location, favorite status)
* `--replace` — like `--add`, but also deletes the original video (moved to Recently Deleted). Mutually exclusive with `--add`.

### Examples

* `shrink-videos --dry-run true` will find a single Motion JPEG video and output information about it
* `shrink-videos --dry-run true --all` will find all Motion JPEG videos and output information about each one
* `shrink-videos --dry-run false` will find a single Motion JPEG video, convert it to HEVC, and save it to `/tmp/`
* `shrink-videos --dry-run false --all` is not yet implemented
