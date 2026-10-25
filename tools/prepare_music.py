#!/usr/bin/env python3
"""Reproduce the licensed, quiet BGM files with ffmpeg (no runtime dependency).

Use --source-dir to reuse downloaded Oggs; otherwise download the pinned public
distribution. Every original is SHA-256 checked before cropping/normalizing.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request


REVISION = "ce4e1d1a517101aed56ea47d9f795a5be1d251cd"
BASE = f"https://raw.githubusercontent.com/Sayshal/minstrel-packs-music-01/{REVISION}/assets/audio/"
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "music"
TRACKS = [
    {"file": "ghost-story", "output": "ghost_story", "title": "Ghost Story", "role": "explore", "isrc": "USUAN1300034", "start": 0.58, "duration": 313.97,
     "sha256": "45a9a16ad0b6a4f23d86687158d708ccf9a35df88d44d590e4b4a3d45ec37d19"},
    {"file": "the-descent", "output": "the_descent", "title": "The Descent", "role": "chase", "isrc": "USUAN1200094", "start": 0.48, "duration": 188.57,
     "sha256": "6f1750d403372b99589cf8d6703c21dcc0ecc2211bd6ceed62ad85fdd3d9d99a"},
    {"file": "teller-of-the-tales", "output": "teller_of_the_tales", "title": "Teller of the Tales", "role": "reunion", "isrc": "USUAN1400020", "start": 0.0, "duration": 205.4,
     "sha256": "b0f2f47864b1b354dec34559e0eb195d7862500aabfb8f01b68d45f2062124b2"},
]


def prepare(track, sources):
    source = sources / (track["file"] + ".ogg")
    if not source.exists():
        with urllib.request.urlopen(BASE + source.name, timeout=90) as response:
            source.write_bytes(response.read())
    if hashlib.sha256(source.read_bytes()).hexdigest() != track["sha256"]:
        raise ValueError("Source checksum mismatch: " + source.name)
    command = ["ffmpeg", "-hide_banner", "-nostats", "-v", "info", "-ss", str(track["start"]), "-t", str(track["duration"]), "-i", str(source)]
    analysis = subprocess.run(command + ["-af", "loudnorm=I=-21:TP=-6:LRA=7:print_format=json", "-f", "null", "-"], capture_output=True, text=True, check=True)
    measured = json.loads(re.findall(r"\{[^{}]*\}", analysis.stderr)[-1])
    normalize = "loudnorm=I=-21:TP=-6:LRA=7:linear=true:measured_I={input_i}:measured_TP={input_tp}:measured_LRA={input_lra}:measured_thresh={input_thresh}:offset={target_offset}".format(**measured)
    filters = normalize + f",afade=t=in:d=0.25,afade=t=out:st={track['duration'] - 0.7}:d=0.7"
    output = OUT / (track["output"] + ".ogg")
    subprocess.run(command + ["-y", "-af", filters, "-ar", "44100", "-ac", "2", "-c:a", "libvorbis", "-q:a", "4.5",
                   "-metadata", "title=" + track["title"], "-metadata", "artist=Kevin MacLeod", "-metadata", "license=CC BY 4.0",
                   "-metadata", "copyright=Kevin MacLeod (incompetech.com)", str(output)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
    entry = dict(track)
    entry.update({"author": "Kevin MacLeod (incompetech.com)", "license": "CC-BY-4.0", "license_url": "https://creativecommons.org/licenses/by/4.0/",
                  "original_page": "https://incompetech.com/music/royalty-free/index.html?isrc=" + track["isrc"], "download": BASE + source.name,
                  "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(), "modifications": "Silent-edge crop, loudness normalization to -21 LUFS / -6 dBTP / 7 LU LRA, short fades, Ogg Vorbis transcode. Runtime looping and crossfades."})
    print(track["title"], output.stat().st_size, "bytes", flush=True)
    return entry


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mirror-music-") as temporary:
        sources = args.source_dir or Path(temporary)
        manifest = [prepare(track, sources) for track in TRACKS]
    (OUT / "sources.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
