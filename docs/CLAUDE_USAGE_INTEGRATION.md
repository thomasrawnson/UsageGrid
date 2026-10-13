# Claude usage integration proof

UsageGrid can passively capture the [documented Claude Code status-line quota fields](https://code.claude.com/docs/en/statusline). It requires the Claude Code CLI and a subscription/session eligible to receive those usage fields. It does not call Anthropic, read Claude credentials, send prompts, or modify Claude Code settings. The integration is opt-in, experimental, and is not production approval.

UsageGrid cannot determine from the absence of a snapshot whether Claude Code is installed, authenticated, configured, or currently returning eligible usage fields. The in-app Claude panel therefore reports these as possible causes rather than claiming a specific diagnosis.

## What is stored

The capture helper accepts Claude Code's status-line JSON on standard input, validates the documented `five_hour` and `seven_day` windows, and writes only:

- the two usage percentages and reset epochs that are present;
- a sanitized Claude Code source version, when present;
- snapshot capture time;
- the first local time at which the current set of quota values was observed.

The complete input is never written. Session IDs, prompt IDs, transcripts, workspace paths, account data, costs, model data, credentials, and unknown fields are discarded. The snapshot is stored at `~/Library/Application Support/UsageGrid/claude-usage-snapshot.json`; its directory and file permissions are set to `0700` and `0600` respectively.

`capturedAt` means the helper received a payload at that time. It is not a provider measurement timestamp. Claude Code does not include such a timestamp. When an identical payload is received again, `capturedAt` advances but `measurementObservedAt` does not. UsageGrid therefore does not present repeated identical status-line executions as newly measured server usage.

## Build the capture helper

From this repository:

```sh
swift build -c release --product UsageGridClaudeCapture
```

The helper is emitted at `.build/release/UsageGridClaudeCapture`. Move or copy it to a stable location you control before opting in. UsageGrid does not bundle or install a stable helper path and therefore does not invent one in its setup UI. It never edits Claude settings for you.

## Opt-in with no existing status line

After reviewing and backing up `~/.claude/settings.json`, manually add a `statusLine` command using the helper's absolute path:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/UsageGridClaudeCapture --display"
  }
}
```

This makes the helper the visible status line. It prints only the captured quota summary. Claude Code supplies quota fields only for supported subscription sessions and only after the first API response, so an initial capture may be unavailable.

## Coexist with an existing status line

Claude Code has one `statusLine.command`; back up the exact current setting and do not overwrite an existing command. Instead, manually create and review a wrapper that sends the in-memory payload to both commands. Replace both paths below. Do not write the input to a temporary file.

```sh
#!/bin/sh
input=$(cat)
printf '%s' "$input" | /absolute/path/to/UsageGridClaudeCapture >/dev/null 2>&1 || true
printf '%s' "$input" | /absolute/path/to/existing-status-line
```

Make the wrapper executable, test it with synthetic input, and then explicitly point `statusLine.command` at the wrapper. This preserves the existing command's output. The shell variable holds the payload only for the life of that invocation; the wrapper must not log or echo it.

## Refresh and removal

UsageGrid's Claude Refresh button only rereads the local snapshot. It does not contact Claude and cannot make an unchanged quota measurement fresher. A newer snapshot depends on Claude Code running the configured status-line command; quota fields depend on Claude Code having received a provider response.

To remove the integration, restore the exact backed-up `statusLine` setting (or remove only the setting you manually added). Do not remove unrelated keys from Claude Code settings. Then remove the helper or wrapper if desired. The snapshot may be deleted separately without changing Claude authentication:

```sh
rm "$HOME/Library/Application Support/UsageGrid/claude-usage-snapshot.json"
```

Review the exact path before deleting it. Removal is manual and reversible from the settings backup.
