# MCP Dependency Removal — Implementation Record

**Status:** Complete (2026-07-24)

## Goal

Remove the Builder App's FastMCP/in-process Databricks tool registration while
preserving Databricks development through project skills and authenticated
command-line workflows.

## Decision

The Builder App now follows the Solution Builder execution model:

- `ClaudeAgentOptions(mcp_servers={})`
- Project skills loaded with the built-in `Skill` tool
- Databricks CLI and short Python SDK scripts executed through `Bash`
- Project-only Claude settings, with project MCP discovery explicitly disabled

The standalone `databricks-mcp-server/` package is unchanged. This migration
only removes the Builder App's vendored `packages/databricks_agent_tools` and
its agent wiring.

## Implemented changes

1. Removed the in-process FastMCP loader and `mcp__databricks__*` allowlists.
2. Enabled `Bash` and retained project-scoped file tools plus `Skill`.
3. Deleted the vendored agent tool wrappers, async operation tracker, and
   obsolete Builder App tool service.
4. Removed the direct `fastmcp` dependency. The `mcp` package may still appear
   transitively through `claude-agent-sdk`; it is not configured at runtime.
5. Added project-scoped CLI authentication:
   - local: selected Databricks profile token
   - Apps: `X-Forwarded-Access-Token`
   - `.databrickscfg` written atomically with mode `0600`
   - inherited Apps service-principal credentials scrubbed for the subprocess
6. Forced project settings to `enableAllProjectMcpServers: false` and
   `mcpServers: {}` in local and deployed modes.
7. Updated the system prompt to make skills + CLI the authoritative execution
   architecture and removed old tool-name instructions.

## Verification

| Check | Result |
|-------|--------|
| CLI-only/auth regression suite | Pass |
| Local Skill + Bash smoke test | Pass |
| Local project CLI profile mode | `0600` |
| Apps deployment | Pass |
| Apps response reports CLI-only architecture | Pass |
| `mcp__databricks__*` tools registered | None |
| Standalone `databricks-mcp-server/` modified | No |

## Remaining operational checks

- Exercise representative SQL, Unity Catalog, jobs, and pipeline workflows to
  validate upstream skill coverage.
- Continue to constrain Bash execution as the application moves beyond trusted
  internal users.

## Out of scope

- Replacing Claude Agent SDK
- Removing the skills system
- Modifying the standalone MCP server package
- Changing Lakebase or FMAPI architecture beyond the auth work needed for
  local/deployed parity
