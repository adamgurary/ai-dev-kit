# Plan: Deployed Builder App Parity (Local Works / Deploy Fails)

**Date:** 2026-07-23  
**Goal:** Make the Databricks Apps–deployed builder-app behave like the working local app, without breaking local. Prefer deploy-only code paths where needed. Borrow proven patterns from [solution-builder](https://github.com/databricks-solutions/solution-builder).

**Reference clone:** `/tmp/solution-builder` (main)  
**Our app:** `ai-dev-kit/databricks-builder-app`

---

## Diagnosis summary

Local works because disk and Claude config persist under the developer home (`~/.claude`, project dirs on a real filesystem). Deployed Apps containers are ephemeral: home and project dirs die on restart/redeploy. The DB still holds Claude `session_id` values that point at conversations that no longer exist on disk → Claude CLI exits with:

```text
No conversation found with session ID: …
ProcessError: exit code 1
```

solution-builder already documents and fixes this exact failure with deploy-only `CLAUDE_CONFIG_DIR` + syncing transcript files into durable storage.

Several secondary bugs compound the UX on deploy (`/api/me` 404, backup worker crash, title-gen 401).

---

## P0 — Must fix for deploy chat to work

### 1. Session resume soft-fail + clear stale IDs

**Symptom:** Agent invoke crashes when DB has a `session_id` whose transcript is gone after container restart.

**Change (safe for local):**
- In `server/routers/agent.py` / `server/services/agent.py`: if Claude stderr/error contains `No conversation found with session ID`, clear `conversation.session_id` in DB and retry once **without** `resume`.
- Do not change local happy-path resume when transcripts exist.

**Why first:** Unblocks users immediately even before durable session storage lands.

### 2. Deploy-only `CLAUDE_CONFIG_DIR` under project dir

**solution-builder pattern** (`backend/services/agent.py`):

```python
if mode == "deployed":
    env["CLAUDE_CONFIG_DIR"] = str(project_dir / ".claude")
```

**Why deploy-only:** Locally, relocating config cuts off `claude login` / Keychain → “Not logged in”. Local `~/.claude` already persists across restarts.

**Change:**
- Detect deployed mode (prefer Apps identity header / existing `is_production` / `DATABRICKS_CLIENT_ID` — align with whatever builder-app already uses; solution-builder prefers `x-forwarded-access-token` for mode).
- Set `CLAUDE_CONFIG_DIR` only in deployed mode when building ClaudeSDK options env.

### 3. Persist Claude transcripts across restarts

**solution-builder pattern** (`file_watcher.py`):
- Sync `.claude/projects/**` (transcripts) and `.claude/.claude.json` into Lakebase/DB.
- Explicitly **do not** sync skills, settings, credentials, statsig, todos, backups, FMAPI token files.

**Change for builder-app:**
- Fix backup worker first (P0.4), then ensure zip backup **includes** `.claude/projects/**` and `.claude/.claude.json`.
- Optionally ignore regenerable/auth material (skills copy, token helpers) to keep backups small — match solution-builder ignore list where it makes sense.
- On project open / app startup restore: restore zip before any resume.

### 4. Fix backup `utc_now` crash

**Symptom:** `Backup failed: utc_now() missing 1 required positional argument: 'ctx'`

**Location:** `server/services/backup_manager.py` ~line 96:

```python
'updated_at': ProjectBackup.updated_at.default.arg(),
```

**Change:** Use `datetime.now(timezone.utc)` (or the app’s existing `utc_now` helper called correctly). Without this, project FS restore fails and session persistence never sticks.

---

## P1 — UX / identity / secondary auth

### 5. Fix `/api/me` path mismatch

**Frontend:** `client/src/lib/api.ts` → `GET /api/me`  
**Backend:** `config_router` mounted at `/api/config` → actual route is `GET /api/config/me`

**Change (pick one):**
- A) Mount a thin alias: `app.include_router` or `@app.get("/api/me")` forwarding to the same handler (matches solution-builder `/api/me`).
- B) Change frontend to `/config/me`.

Prefer **A** for API clarity and parity with solution-builder.

### 6. Title generation 401

**Symptom:** `Title generation failed: … 401 Credential was not sent or was of an unsupported type`

Agent FMAPI path can work (OAuth bearer present) while `title_generator.py` still uses a client that doesn’t send the same credential.

**Change:**
- Align title generator with the working agent auth path (same token source / base URL / model).
- Longer-term: adopt solution-builder `fmapi_auth.py` (settings.json + `apiKeyHelper`) so **all** Anthropic-facing callers share one mechanism and subprocess env stays clean.

### 7. Deploy-only FMAPI via project settings (solution-builder `fmapi_auth`)

**Why:** Env `ANTHROPIC_*` on the agent subprocess can bleed into `databricks` CLI calls. solution-builder writes:

```text
<project>/.anthropic_token
<project>/get_anthropic_token.sh
<project>/.claude/settings.json   # apiKeyHelper + ANTHROPIC_BASE_URL + MODEL
```

Refresh token every ~15 min from SP OAuth. **Local:** skip entirely (developer API key / login).

**Change:** Port a slim `fmapi_auth` module; call `ensure_fmapi_auth_files(project_dir)` before Claude client create in deployed mode only. Keep current env-var path as fallback until verified.

---

## P2 — Hardening / product quality (mimic solution-builder)

| Idea | Why | Local impact |
|------|-----|--------------|
| **Client pool** keyed by `project_id` | Reuse SDK clients; faster turns; fewer cold starts | Optional; local can keep one-shot |
| **Stderr buffer on ProcessError** | Already partially done; attach tail to user-facing errors | Safe |
| **Path-scoped Read/Write/Edit** | Deny writes outside `project_dir` | Safe; improves both modes |
| **Central `detect_mode()`** | Header-based local vs deployed (AUTH.md) | Clarifies branching |
| **Per-project `.databrickscfg` in deploy** | User token from `x-forwarded-access-token` for agent CLI | Deploy-only |
| **Clear-session API** | UI reset when resume is hopeless | Both |
| **Explicit `setting_sources=["project"]`** | Already on deploy; keep local able to use user settings if desired | Document split |
| **Venv-first PATH** for agent Bash | Apps injects PATH that demotes `.venv` | Deploy-focused |
| **Transcript re-anchoring** | After redeploy, cwd path under `.claude/projects/` changes; fold old dirs into current | Deploy-only |
| **SSE keepalives** | Prevent proxy timeouts during long tool runs | Both |
| **Skills in wheel** | Avoid Apps file-list timeouts from hundreds of loose skill files | Deploy packaging |

### P2b — Deploy packaging (from solution-builder build pipeline)

solution-builder ships **`pyproject.toml` + `uv.lock` only** (no `requirements.txt`). On Apps, a `requirements.txt` forces **pip + Python 3.11** and ignores `requires-python`. Builder-app still leans on `requirements.txt` / `deploy.sh` — evaluate migrating to uv-lock-based bundle deploy with `requires-python = ">=3.12,<3.13"` and a Linux-only `start.sh` separate from local `dev.sh`.

---

## Recommended implementation order

```text
Phase A (unblock deploy this week) — DONE
  1. Soft-fail stale session_id + retry without resume
  2. Fix backup utc_now
  3. Alias GET /api/me
  4. Fix title_generator auth to match agent FMAPI

Phase B (durable sessions — matches solution-builder) — DONE 2026-07-24
  5. Deploy-only CLAUDE_CONFIG_DIR = project/.claude
  6. Backup/restore includes .claude/projects; excludes skills/creds/caches
  7. Transcript re-anchoring after restore; await restore before resume

Phase C (auth architecture) — DONE
  8. Port fmapi_auth (settings.json + apiKeyHelper), deploy-only
  9. Stop relying on ANTHROPIC_* env for Claude subprocess in deploy

Phase D (polish) — PARTIAL 2026-07-24
 10. Path allowlist (dontAsk + can_use_tool), clear-session API, AUTH.md
 11. Orphan execution cancel after restart; client reconnect cleanup
 12. Deferred: ClientPool (different invoke model), FMAPI background refresh, uv-lock packaging
```

---

## Local vs deploy branching (explicit)

| Concern | Local | Deployed |
|---------|-------|----------|
| Claude config dir | default `~/.claude` | `CLAUDE_CONFIG_DIR=<project>/.claude` |
| Anthropic auth | `ANTHROPIC_API_KEY` / login | FMAPI via settings.json + helper (target) |
| Databricks CLI auth | profile / user PAT | per-project `.databrickscfg` from forwarded token (target) |
| Session durability | home disk | DB backup of project + `.claude/projects` |
| `setting_sources` | can include user | `["project"]` only |

Gate on one helper, e.g. `is_deployed_mode()`, so local paths never get `CLAUDE_CONFIG_DIR` relocation.

---

## Verification plan

1. **Local regression:** create project, multi-turn chat, resume after server restart — unchanged.
2. **Deploy:** new project, multi-turn, note `session_id`; force app restart/redeploy; reopen project — either resumes or starts clean without ProcessError.
3. **Deploy:** `GET /api/me` returns 200 with email/mode.
4. **Deploy:** backup worker logs success; project files survive restart.
5. **Deploy:** new conversation gets a title (no 401).

---

## Out of scope / do not break

- Do not relocate `CLAUDE_CONFIG_DIR` in local mode.
- Do not require FMAPI settings.json when `ANTHROPIC_API_KEY` is the local path.
- Do not wholesale replace builder-app architecture with solution-builder — port patterns surgically.
