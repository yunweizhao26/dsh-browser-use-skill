# Recordings and video

Fresh installs record nothing. Locally captured action traces are opt-in, and a recording is only made when the user asks for one — "record", "show", "make a video", "demo". Significant work by itself is **not** consent, and never re-enact a finished task to produce a video.

## Enable or inspect

```powershell
browser-use recordings           # status, active dir, latest
browser-use recordings enable    # record every session locally
browser-use recordings disable
```

`BH_RECORD=1` / `BH_RECORD=0` overrides the stored preference for one process.

## Capture a task

1. Before browser work: `start_recording(name, title=…)` and keep the **exact** directory it returns.
2. Do the work normally, verify the result.
3. After verification: `stop_recording()`.

Never substitute `recordings --latest` for the returned path. For a request made after the fact you may use `browser-use recordings --latest`, but only if its timestamps and pages match the work; otherwise say plainly that it was not captured.

## Video

Editing and export are a separate pipeline (`browser-use video init/review/export`, reviewed before an MP4 is produced). Follow https://github.com/browser-use/browser-harness/blob/main/interaction-skills/make-video.md for the post-production steps. If sub-agents are available they can do post-production from the exact recording path while the main agent returns the task result.
