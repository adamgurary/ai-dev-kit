# MCP Dependency Removal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the builder-app’s dependency on the MCP/FastMCP tool registration path while keeping Databricks building capabilities (skills + callable tools) working in both local and deployed modes.

**Architecture:** Today tools are **already in-process** (`create_sdk_mcp_server` → `mcp_servers={'databricks': ...}`). There is no Databricks MCP subprocess. The “MCP dependency” is the FastMCP registry + `mcp__databricks__*` naming + skill↔tool allowlist bridging. Target end state: either (A) keep thin in-process SDK tools without FastMCP, or (B) skill/CLI-only like solution-builder (`mcp_servers={}`).

**Tech Stack:** `claude-agent-sdk`, vendored `databricks_agent_tools` / `databricks_tools_core`, project skills under `.claude/skills/`, builder-app `server/services/{agent,databricks_tools,skills_manager}.py`

---

## Current state (facts)

1. **No MCP child process** for Databricks tools in the agent path.
2. Tools are registered via FastMCP `@mcp.tool`, then wrapped into SDK tools and exposed as `mcp__databricks__{name}`.
3. Skills primarily document **CLI/Bash** workflows; enablement also **filters** which MCP tool names are allowed (`get_allowed_mcp_tools`).
4. Solution-builder uses `mcp_servers={}` and relies on skills + Bash/CLI — simpler, but loses structured tool schemas / async handoff.

## Decision needed (pick one before coding)

| Option | What changes | Pros | Cons |
|--------|--------------|------|------|
| **A — Collapse FastMCP, keep in-process SDK tools** (recommended) | Replace FastMCP discovery with plain Python tool defs / SDK `@tool`; keep `create_sdk_mcp_server` or pass tools natively if SDK allows; drop `fastmcp` package | Keeps structured tools, async handoff, skill filtering; removes FastMCP version fragility | Still uses SDK’s MCP *transport* name (`mcp__…`) unless SDK has non-MCP tool injection |
| **B — Skills + CLI only** | Set `mcp_servers={}`; delete/ignore tool wrappers; teach skills to use `databricks` CLI / Python SDK via Bash | Matches solution-builder; smallest surface | Weaker guarantees, harder long-running ops, more token use, Bash path allowlisting becomes critical |
| **C — Hybrid** | Keep a small core of in-process tools (SQL, UC, Jobs); move niche ops to skills/CLI | Pragmatic migration | Two systems to maintain during transition |

**Recommendation:** **A**, then optionally thin toward **C**. Do not jump to B until path allowlist + Bash sandboxing are proven on deploy.

---

### Task 1: Inventory tools vs skills

**Files:**
- Read: `packages/databricks_agent_tools/tools/**/*.py`
- Read: `server/services/skills_manager.py` (skill→tool map)
- Create: `docs/plans/mcp-tool-inventory.md`

**Step 1:** List every registered tool name and which skill (if any) gates it.  
**Step 2:** Mark tools with no skill mapping (always-on, e.g. `execute_sql`).  
**Step 3:** Commit inventory.

---

### Task 2: Define non-FastMCP tool registry

**Files:**
- Create: `server/services/tool_registry.py`
- Test: `tests/test_tool_registry.py`

**Step 1:** Write failing tests that load tools without importing `databricks_agent_tools.server.mcp`.  
**Step 2:** Implement a registry that imports callables from `databricks_tools_core` / thin wrappers and builds SDK `tool(...)` entries.  
**Step 3:** Preserve async handoff (`SAFE_EXECUTION_THRESHOLD` / operation tracker) from `databricks_tools.py`.

---

### Task 3: Rewire agent to new registry

**Files:**
- Modify: `server/services/agent.py`
- Modify: `server/services/databricks_tools.py` (delegate or delete)
- Test: update `tests/test_skills_manager.py`

**Step 1:** `load_databricks_tools()` uses `tool_registry` only.  
**Step 2:** Keep `mcp_servers={'databricks': server}` until SDK supports another injection path (document as “in-process MCP shim”).  
**Step 3:** Confirm skill filtering still produces correct allowlists.

---

### Task 4: Remove FastMCP package dependency

**Files:**
- Modify: `requirements.txt` / `pyproject.toml`
- Modify/Delete: `packages/databricks_agent_tools/server.py` FastMCP usage if unused
- Test: import smoke + agent unit tests

**Step 1:** Ensure no runtime import of `fastmcp`.  
**Step 2:** Drop dependency from deploy bundle.  
**Step 3:** Verify local + deploy cold start.

---

### Task 5 (optional follow-on): Skill/CLI migration for niche tools

**Files:** skills under `skills/` / `.claude/skills/`

**Step 1:** For low-use tools, expand skill docs to CLI recipes.  
**Step 2:** Remove those tools from registry.  
**Step 3:** Regression: build a pipeline / run SQL / create job in local + deploy.

---

### Task 6: Verification matrix

| Check | Local | Deploy |
|-------|-------|--------|
| New chat + SQL / UC action | ✓ | ✓ |
| Skill-gated tool appears only when skill enabled | ✓ | ✓ |
| Long tool (>10s) async handoff still works | ✓ | ✓ |
| No `fastmcp` in process/deps | ✓ | ✓ |
| Path allowlist still blocks writes outside project | ✓ | ✓ |

---

## Out of scope

- Replacing Claude Agent SDK
- Removing skills system
- Changing Lakebase / FMAPI auth (Phases A–C)

## Open question for product

Should the long-term UX prefer **structured tools** (Option A/C) or **skill-driven CLI** (Option B)? That choice drives whether Bash hardening is P0 for this removal.
