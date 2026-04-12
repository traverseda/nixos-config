# Nanobot Home-Manager Configuration

This directory contains the Home-Manager configuration for `nanobot`, a sandboxed AI assistant integrated into a NixOS environment.

## Architecture & Goals

The primary goal of this setup is to provide a highly capable AI agent that has access to local tools and state while maintaining a strict security boundary.

### 1. The Sandbox (Firejail)
To prevent the LLM from having unrestricted access to the host system, the `nanobot` binary is wrapped in a **Firejail** sandbox.
- **Capabilities**: All kernel capabilities are dropped (`--caps.drop=all`).
- **Filesystem**: Access is restricted using a whitelist approach. Only `~/.nanobot` and the MCP runtime directory are accessible.
- **Hardware**: Access to 3D acceleration, DVD, sound, TV, U2F, and video devices is disabled.

### 2. Environment & Secrets (The Login Shell Pattern)
The configuration uses a specific execution pattern to handle secrets (like API keys) and environment variables:
- **Login Shell Wrapper**: The entry point uses `bash -li -c`. This ensures that the environment is initialized as a login shell, which is necessary for sourcing secrets managed by tools like KWallet, keychain, or other environment-based secret managers that hook into shell initialization.
- **Explicit Passing**: Key variables (e.g., `OPENROUTER_API_KEY`, `XDG_RUNTIME_DIR`) are explicitly captured from the host environment and passed into the Firejail sandbox via `--env` flags. This creates a "Secret-Aware" bridge where the sandbox only sees what it is explicitly granted.

### 3. State & Persistence
The agent's state is persisted in `~/.nanobot`:
- **`memory/`**: Contains long-term facts (`MEMORY.md`) and a full interaction history (`history.jsonl`).
- **`skills/`**: Custom executable skills that extend the agent's capabilities.
- **`sessions/`**: Context and state for active chat sessions.
- **`HEARTBEAT.md`**: A task list checked periodically by the system to trigger background actions.

## File Structure

- `nanobot.nix`: The main module defining the `nanobot` service and its environment.
- `mcp_tools.nix`: Defines the list of MCP tools, their required environment variables, and specific `firejail` arguments.
- `nanobot_gateway.nix`: Handles the gateway logic and socket-bridge connections.
- `tools/`: Implementation logic for individual MCP tools.

## Usage in NixOS
This configuration is deployed via Home-Manager, using `writeShellScriptBin` to generate the sandboxed wrapper that orchestrates the login shell, environment variables, and Firejail constraints.
