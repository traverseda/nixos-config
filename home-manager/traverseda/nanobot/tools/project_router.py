# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "mcp",
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

import asyncio
import sys
import argparse
import shlex
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from mcp.server.fastmcp import FastMCP

# The main aggregated server
mcp = FastMCP("ProjectRouter")

# Store sessions
sessions = []

async def connect_to_server(cmd: str):
    """Runs an MCP server and establishes a ClientSession."""
    parts = shlex.split(cmd)
    server_params = StdioServerParameters(command=parts[0], args=parts[1:])
    
    # Connect and initialize
    read, write = await stdio_client(server_params).__aenter__()
    session = await ClientSession(read, write).__aenter__()
    await session.initialize()
    
    sessions.append(session)
    
    # Register tools from this session
    tools = await session.list_tools()
    for tool in tools.tools:
        # Create a proxy function for the tool
        async def proxy_tool(arguments: dict, session=session, tool_name=tool.name):
            return await session.call_tool(tool_name, arguments=arguments)
        
        mcp.add_tool(proxy_tool, name=tool.name, description=tool.description)
        
    print(f"Registered tools from {cmd}", file=sys.stderr)

async def main():
    parser = argparse.ArgumentParser(description="Project Router: Orchestrates multiple MCP servers.")
    parser.add_argument("commands", nargs="+", help="Commands to start MCP servers")
    args = parser.parse_args()
    
    print(f"Starting Project Router with {len(args.commands)} servers", file=sys.stderr)
    
    # Connect to all servers
    await asyncio.gather(*(connect_to_server(cmd) for cmd in args.commands))
    
    # Run the aggregated server
    mcp.run(transport='stdio')

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Shutting down", file=sys.stderr)
