# Prerecorded Swedish lesson audio and images

Swedish speech is generated locally using Piper `sv_SE-nst-medium`. The publisher’s model card identifies the NST Swedish dataset as CC0 and credits training from scratch to KBLab at the National Library of Sweden. The exact downloaded checkpoint hash and synthesis settings are recorded in the media manifest. This is synthetic audio, not recordings made by an app narrator.

- https://huggingface.co/rhasspy/piper-voices/blob/main/sv/sv_SE/nst/medium/MODEL_CARD
- https://www.nb.no/sprakbanken/en/resource-catalogue/oai-nb-no-sbr-17/

English uses the same `en_US-ljspeech-high` model and verified recordings as the Finnish app for matching English text. The publisher identifies LJ Speech as public domain. The source model hash must match before a recording is reused.

- https://huggingface.co/rhasspy/piper-voices/blob/main/en/en_US/ljspeech/high/MODEL_CARD
- https://keithito.com/LJ-Speech-Dataset/

Piper 1.8.0, ONNX Runtime, FFmpeg and the voice checkpoints are development tools. They are not included in the phone application or public media packs. Preserve the individual model cards and dataset information with the release; a repository-wide label does not replace them.

- https://github.com/OHF-Voice/piper1-gpl

Images are full-dimension WebP quality-85 distribution copies of the reviewed Swedish card artwork. Original PNG masters and bundled JPEG source files are retained unchanged. Text, learning IDs and lesson meanings are unchanged by media packaging.

Automated format, duration, coverage and checksum checks do not certify perfect Swedish pronunciation. Listening review remains part of pre-release quality review.
