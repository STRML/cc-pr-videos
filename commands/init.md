---
description: "Set up PR demo recording for the current project"
---

# PR Demo Video Setup

Set up automatic PR demo recording for this project.

## Steps

1. **Create `.claude/demo.json`** in the project root with this template (ask the user to fill in auth details if needed):

```json
{
  "baseUrl": "http://localhost:3000",
  "auth": {
    "loginUrl": "/login",
    "username": "",
    "password": ""
  },
  "browserState": ".claude/demo-browser-state.json",
  "outputDir": ".claude/videos",
  "hints": ""
}
```

- `baseUrl`: The dev server URL (probe ports 3000, 3001, 5173, 5174, 8080 to suggest one)
- `auth`: Login credentials for the app. Omit the entire `auth` key if no login is needed.
- `browserState`: Path to save/load browser cookies between recordings
- `outputDir`: Where to save recordings (default: `.claude/videos`). Videos are named `pr-{num}-{repo}-{topic}.webm`.
- `hints`: Free-text hints for the recorder (e.g. "The new feature is at /settings/billing")

2. **Add the sentinel file instruction** to the project's `.claude/CLAUDE.md` (create if it doesn't exist). Append this block if a "PR Demo Recording" section is not already present:

    ## PR Demo Recording

    After any `gh pr create` succeeds and you have the PR URL, write it to a sentinel file:

        echo "$PR_URL" > /tmp/claude/pr-demo-pending

    Then tell the user: "PR demo queued — will record to ~/Desktop/pr-demo-<N>.webm after this response."

    A Stop hook picks up the sentinel and launches the recorder outside the sandbox.

    ### Embedding the recording in the PR

    GitHub strips `<video>` tags from PR descriptions. To embed the demo as an auto-playing preview, convert to GIF and use `![]()` markdown:

        # Convert to GIF (720px wide, 10fps, palette-optimized)
        ffmpeg -y -i ~/Desktop/pr-demo-<N>.webm \
          -vf "fps=10,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" \
          -loop 0 /tmp/pr-demo.gif

        # Upload to catbox.moe and get a URL
        curl -s -F "reqtype=fileupload" -F "fileToUpload=@/tmp/pr-demo.gif" https://catbox.moe/user/api.php

        # Paste the returned URL into the PR body as: ![Demo](https://files.catbox.moe/abc123.gif)

3. **Add these entries to `.gitignore`** (they contain credentials, session data, or generated files):
   - `.claude/demo-browser-state.json`
   - `.claude/demo-feedback.log`
   - `.claude/videos/`

4. Tell the user the setup is complete and they can test by creating a PR in this project.
