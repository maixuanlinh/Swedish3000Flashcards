"""Build prerecorded speech and small, immutable media packs. No paid service is used.

Run with the Python environment described in MediaDelivery/README.md. The
canonical Resources directory is read-only; generated files live in MediaDelivery.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import wave
import shutil
import concurrent.futures
import multiprocessing
import atexit

ROOT = Path(__file__).resolve().parents[2]
VOICES = {"sv-SE": "sv_SE-nst-medium", "en-US": "en_US-ljspeech-high"}
FORMAT = "sisu-lesson-media-v1"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def audio_key(language: str, text: str) -> str:
    return f"audio/{language}/{digest(text.encode('utf-8'))}"


def save_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    temp.replace(path)


def load_words():
    def load(name):
        return json.loads((ROOT / "Resources" / name).read_text())
    catalog = load("catalog3000.json")["entries"]
    starters = {w["id"]: w for w in load("starter100.json")}
    examples = {w["id"]: w for w in load("examples3000.json")}
    artwork = {w["wordID"]: w for w in load("BundledArtwork/manifest.json")}
    words = []
    for row in catalog:
        word = dict(row)
        word.update({k: v for k, v in starters.get(row["id"], {}).items() if k in ("english", "swedish")})
        word["sentence"] = examples[row["id"]]["sentence"]
        word["images"] = [artwork[row["id"]]["filename"], artwork[row["id"]]["thumbnailFilename"]]
        word["starter"] = row["id"] in starters
        words.append(word)
    assert len(words) == 3000 and len({w["id"] for w in words}) == 3000
    return sorted(words, key=lambda w: (not w["starter"], w["sourceID"]))


def voice_runtime(models: Path):
    import onnxruntime as ort
    import piper
    from piper.config import PiperConfig
    ort.disable_telemetry_events()
    # Some macOS wheels cannot initialize eSpeak with a long data directory.
    # Use a short, private temporary link rather than modifying the wheel/system.
    short = Path(tempfile.mkdtemp(prefix="sisu-speech-"))
    data = Path(piper.__file__).parent / "espeak-ng-data"
    (short / "espeak-ng-data").symlink_to(data.resolve(), target_is_directory=True)
    os.environ["ESPEAK_DATA_PATH"] = str(short)
    voices = {}
    for language, name in VOICES.items():
        path = models / (name + ".onnx")
        options = ort.SessionOptions()
        options.intra_op_num_threads = 1
        options.inter_op_num_threads = 1
        voices[language] = piper.PiperVoice(
            config=PiperConfig.from_dict(json.loads(path.with_suffix(".onnx.json").read_text())),
            session=ort.InferenceSession(str(path), sess_options=options, providers=["CPUExecutionProvider"]),
            espeak_data_dir=short / "espeak-ng-data",
        )
    return voices, short


def init_audio_worker(models):
    global _voices, _short, _ffmpeg
    import imageio_ffmpeg
    _voices, _short = voice_runtime(Path(models))
    _ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    def cleanup():
        (_short / "espeak-ng-data").unlink(missing_ok=True)
        _short.rmdir()
    atexit.register(cleanup)


def synthesize_recording(task):
    from piper import SynthesisConfig
    key, language, text, filename = task
    path = Path(filename)
    spoken_text = text.replace(" / ", ", ").rstrip("-") if language == "sv-SE" else text
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav:
        _voices[language].synthesize_wav(spoken_text, wav, syn_config=SynthesisConfig(length_scale=1.05))
    with wave.open(io.BytesIO(buffer.getvalue()), "rb") as wav:
        seconds = wav.getnframes() / wav.getframerate()
    if not .12 < seconds < 45:
        raise ValueError(f"Unusual recording duration for {key}: {seconds}")
    encoded = subprocess.run([_ffmpeg, "-v", "error", "-i", "pipe:0",
        "-af", "apad=pad_dur=0.12", "-ac", "1", "-ar", "22050", "-codec:a", "libmp3lame", "-b:a", "64k",
        "-map_metadata", "-1", "-f", "mp3", "pipe:1"], input=buffer.getvalue(), capture_output=True, check=True).stdout
    assert len(encoded) > 1000
    temporary = path.with_suffix(".tmp")
    temporary.write_bytes(encoded)
    temporary.replace(path)
    return key, {"language": language, "text": text, "spokenText": spoken_text,
                 "bytes": len(encoded), "seconds": round(seconds + .12, 3), "sha256": digest(encoded)}


def make_audio(words, work: Path, models: Path):
    requests = {}
    for word in words:
        for language, text in [("sv-SE", word["swedish"]), ("en-US", word["english"]), ("sv-SE", word["sentence"])]:
            requests[audio_key(language, text)] = (language, text)
    config = {"engine": "piper-tts-1.8.0", "encoding": "mp3-64k-mono-22050", "lengthScale": 1.05,
              "tailPaddingSeconds": .12, "models": {k: digest((models / (v + ".onnx")).read_bytes()) for k, v in VOICES.items()}}
    index_path = work / "audio-index.json"
    previous = json.loads(index_path.read_text()) if index_path.exists() else {}
    recordings = previous.get("recordings", {}) if previous.get("config") == config else {}
    prior_work = ROOT.parent / "MediaDelivery/work"
    prior_index = prior_work / "audio-index.json"
    reusable = json.loads(prior_index.read_text()) if prior_index.exists() else {}
    reuse_english = reusable.get("config", {}).get("models", {}).get("en-US") == config["models"]["en-US"]
    audio = work / "audio"
    audio.mkdir(parents=True, exist_ok=True)
    pending = []
    for key, (language, text) in requests.items():
        path = audio / (key.replace("/", "_") + ".mp3")
        old = recordings.get(key)
        if old and path.is_file() and path.stat().st_size == old["bytes"] and digest(path.read_bytes()) == old["sha256"]:
            continue
        prior = reusable.get("recordings", {}).get(key) if language == "en-US" and reuse_english else None
        prior_path = prior_work / "audio" / path.name
        if prior and prior.get("text") == text and prior_path.is_file() and digest(prior_path.read_bytes()) == prior["sha256"]:
            shutil.copy2(prior_path, path)
            recordings[key] = dict(prior, reusedFrom="Finnish release English recording")
        else:
            pending.append((key, language, text, str(path)))
    save_json(index_path, {"config": config, "recordings": recordings})
    print(f"Audio verified/reused: {len(recordings)}/{len(requests)}; generating {len(pending)} with four local workers", flush=True)
    start = time.monotonic()
    try:
        if pending:
            with concurrent.futures.ProcessPoolExecutor(max_workers=4, mp_context=multiprocessing.get_context("spawn"),
                    initializer=init_audio_worker, initargs=(str(models),)) as pool:
                futures = [pool.submit(synthesize_recording, task) for task in pending]
                for number, future in enumerate(concurrent.futures.as_completed(futures), 1):
                    key, record = future.result()
                    recordings[key] = record
                    if number % 100 == 0:
                        save_json(index_path, {"config": config, "recordings": recordings})
                        print(f"Audio {len(recordings)}/{len(requests)}; {time.monotonic()-start:.0f}s", flush=True)
    finally:
        save_json(index_path, {"config": config, "recordings": recordings})
    assert requests.keys() <= recordings.keys()
    print(f"Audio complete: {len(requests)} unique recordings, {sum(recordings[k]['bytes'] for k in requests)/1e6:.1f} MB", flush=True)
    return {key: audio / (key.replace("/", "_") + ".mp3") for key in requests}, config


def make_images(words, work: Path):
    from PIL import Image
    folder = work / "images"
    folder.mkdir(parents=True, exist_ok=True)
    images = {}
    for number, word in enumerate(words, 1):
        for name in word["images"]:
            source = ROOT / "Resources/BundledArtwork" / name
            target = folder / (digest(source.read_bytes() + b"webp-q85-method4") + ".webp")
            if not target.is_file():
                with Image.open(source) as image:
                    out = io.BytesIO()
                    image.save(out, format="WEBP", quality=85, method=4)
                target.write_bytes(out.getvalue())
            images["image/" + name] = target
        if number % 250 == 0:
            print(f"Images {number}/{len(words)}", flush=True)
    return images


def build_packs(words, audio, images, output: Path, config, max_bytes=8_000_000):
    public = output / "public/v1"
    assets_dir = output / "generated/assets"
    public.mkdir(parents=True, exist_ok=True)
    assets_dir.mkdir(parents=True, exist_ok=True)
    records, packs, seen = [], [], set()
    contents = bytearray()
    current_records = []
    current_starter = True

    def flush():
        nonlocal contents, current_records
        if not contents:
            return
        checksum = digest(contents)
        filename = f"pack-{checksum}.bin"
        path = public / filename
        if not path.exists():
            path.write_bytes(contents)
        pack = {"file": filename, "bytes": len(contents), "sha256": checksum, "starter": current_starter}
        packs.append(pack)
        for row in current_records:
            row["pack"] = filename
            records.append(row)
        if current_starter:
            destination = assets_dir / filename
            if not destination.exists():
                os.link(path, destination)
        contents, current_records = bytearray(), []

    for word_index, word in enumerate(words):
        # Stable word groups keep a text/recording correction from shifting every
        # later pack boundary and forcing a complete collection redownload.
        if word_index and word_index % 50 == 0:
            flush()
        if word["starter"] != current_starter:
            flush()
            current_starter = word["starter"]
        word_assets = [("image/" + name, images["image/" + name]) for name in word["images"]]
        for language, text in [("sv-SE", word["swedish"]), ("en-US", word["english"]), ("sv-SE", word["sentence"])]:
            key = audio_key(language, text)
            word_assets.append((key, audio[key]))
        for key, path in word_assets:
            if key in seen:
                continue
            data = path.read_bytes()
            if len(contents) + len(data) > max_bytes:
                flush()
            current_records.append({"key": key, "offset": len(contents), "bytes": len(data), "sha256": digest(data)})
            contents.extend(data)
            seen.add(key)
    flush()
    manifest = {"format": FORMAT, "packs": packs, "assets": records, "audio": config,
                "wordCount": len(words), "recordingCount": len(audio)}
    manifest["version"] = digest(json.dumps(manifest, ensure_ascii=False, sort_keys=True).encode())
    save_json(public / "manifest.json", manifest)
    save_json(assets_dir / "lesson-media.json", manifest)
    names = {p["file"] for p in packs}
    # Only remove stale generated packs in this dedicated output folder.
    for folder in (public, assets_dir):
        for path in folder.glob("pack-*.bin"):
            if re.fullmatch(r"pack-[0-9a-f]{64}\.bin", path.name) and path.name not in names:
                path.unlink()
    report = {"version": manifest["version"], "packs": len(packs), "assets": len(records),
              "audioBytes": sum(p.stat().st_size for p in audio.values()),
              "imageBytes": sum(p.stat().st_size for p in images.values()),
              "totalMediaBytes": sum(p["bytes"] for p in packs),
              "starterBytes": sum(p["bytes"] for p in packs if p["starter"])}
    save_json(output / "size-report.json", report)
    for name in (".htaccess", "index.html"):
        source = output / "hosting" / name
        if source.is_file():
            shutil.copyfile(source, public / name)
    notice = output / "NOTICE.md"
    if notice.is_file():
        shutil.copyfile(notice, public / "NOTICE.txt")
    print(json.dumps(report, indent=2), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", type=Path, default=ROOT / "MediaDelivery/models")
    parser.add_argument("--output", type=Path, default=ROOT / "MediaDelivery")
    parser.add_argument("--audio-only", action="store_true")
    args = parser.parse_args()
    work = args.output / "work"
    work.mkdir(parents=True, exist_ok=True)
    words = load_words()
    audio, config = make_audio(words, work, args.models)
    if not args.audio_only:
        images = make_images(words, work)
        build_packs(words, audio, images, args.output, config)


if __name__ == "__main__":
    main()
