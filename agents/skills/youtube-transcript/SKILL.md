---
name: youtube-transcript
description: Use when a user provides a YouTube URL or asks to transcribe summarize or extract notes from a video.
---

# YouTube Transcript

Use official captions, transcript APIs, or user-provided transcript text first. Do not bypass access controls or download private content.

## Workflow

1. Confirm the requested output: transcript, summary, notes, timestamps, or action items.
2. Fetch transcript text only with approved tools available in the current environment.
3. Preserve source metadata when available: title, channel, URL, and retrieval date.
4. Include timestamps only when grounded in transcript data.
5. Do not store the full transcript unless the user asks for a file.

## Common Mistakes

- Treating social posts about a video as the transcript.
- Inventing timestamps.
- Saving long transcripts into repo docs without explicit user intent.
