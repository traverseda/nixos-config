# MCP Service Architecture: The "Secret-Aware" Sandbox Flow

This document explains how a single MCP (Model Context Protocol) tool is defined, sandboxed, and connected to the `nanobot` gateway within this NixOS configuration.

## Overview

The architecture is designed to solve a specific problem: **How do we give a sandboxed AI tool access to secrets (like API keys) that are managed via interactive shell hooks (e.g., `bash --login`)?**

The solution uses a "Socket-Bridge" pattern:
1. **The Gateway** (`nanobot`) is heavily sandboxed and has no access to secrets.
2. **The Tool** is wrapped in its own sandbox and only loads secrets at the moment of execution.
3. **The Bridge** (`socat` + Unix Sockets) connects the two.

---

## The 5-Layer Execution Flow

When `nanobot` calls a tool (e.g., `homeAssistant`), the following chain triggers:

### 1. The Connection Launcher (`mcp-connect`)
`nanobot` is configured to use `mcp-connect <name>` as its "executable" for every MCP server.
- **Action:** Runs `socat STDIO UNIX-CONNECT:/run/user/1000/mcp/<name>.sock`.
- **Purpose:** Bridges the gateway's standard input/output to a local Unix socket.

### 2. The Socket Listener (Systemd + `socat`)
Each tool has a background systemd user service (defined via `mkMcpService` in `nanobot_tools.nix`).
- **Action:** Runs `socat UNIX-LISTEN:... EXEC:"bash --login ..."`.
- **Purpose:** It waits for a connection on the socket. When one arrives, it **forks** and starts a new process.

### 3. The Secret Loader (`bash --login`)
Because `socat` uses `EXEC` with a login shell:
- **Action:** Bash starts and sources your `.bash_profile` / `.zprofile`.
- **Purpose:** This triggers your **profile hooks** (e.g., bitwarden-cli, keychain, or custom scripts) to populate environment variables like `HOME_ASSISTANT_API_KEY`.

### 4. The Sandbox Wrapper (`firejail`)
The login shell executes the `execScript` generated for that tool.
- **Action:** Runs `firejail --env=SECRET=$SECRET ... <tool-binary>`.
- **Purpose:** It "traps" the process. Even though we just loaded secrets, `firejail` ensures the tool can't wander around your home directory or access the network (unless explicitly allowed). It passes only the specific environment variables required.

### 5. The Implementation (`uv2nix` VirtualEnv)
The final process is the actual Python or Rust binary.
- **Action:** The script runs inside a Nix-native virtual environment.
- **Purpose:** Provides the actual MCP logic (e.g., `nix.py`). Since it was built with `uv2nix`, all dependencies are locked and reproducible in the Nix store.

---

## File Responsibilities

### `home-manager/.../nanobot.nix`
- **The Manifest:** Defines the list of tools, their required environment variables, and their specific `firejail` arguments (e.g., `--private` or `--net=none`).

### `home-manager/.../nanobot_tools.nix`
- **The Factory:** Contains the Nix logic to:
    - Build the `uv2nix` environments (`mkUvScriptEnv`).
    - Generate the Systemd service units (`mkMcpService`).
    - Create the `mcp-connect` bridge script.

### `./tools/` directory
- **The Logic:** Contains the actual scripts (like `nix.py`). These files often contain inline PEP 723 metadata (dependencies) which `uv2nix` uses to build the environment.

---

## Key Benefits
- **Security:** The main AI gateway never sees your API keys.
- **Isolation:** Each tool has its own filesystem and network rules.
- **Compatibility:** Works with any secret-management system that hooks into a login shell.
- **Cleanliness:** Tools are started on-demand and cleaned up by systemd.
