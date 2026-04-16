# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "mcp",
#   "loguru",
#   "typer",
# ]
# ///

# # Project Router (project_mcp)

# This tool acts as a dynamic MCP server orchestrator. It is designed to be run
# on-demand within a project directory to expose project-specific MCP servers
# via Unix domain sockets.

# ## Functionality
# 1. **Socket Management**: Creates and manages a Unix domain socket at `$XDG_RUNTIME_DIR/project.sock`.
# 2. **Orchestration**: Spawns multiple MCP servers as child processes.
# 3. **Aggregation**: Acts as a proxy/router, forwarding MCP requests to the appropriate sub-servers and aggregating their tools/resources.

# ## Usage
# project_mcp "<cmd1>" "<cmd2>" ...

# ## Example
# project_mcp "python3 server1.py" "node server2.js --opt"

# ## Behavior
# - The tool creates a socket at `$XDG_RUNTIME_DIR/project.sock`.
# - It spawns each provided command as a subprocess.
# - It aggregates the tools/resources from all subprocesses and exposes them through the created socket.
# - When the process is terminated, it cleans up the socket.
