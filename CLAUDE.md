# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Roblox game project built with Rojo 7.7.1. The codebase uses Luau (Roblox's typed Lua dialect) and follows the standard client/server/shared architecture pattern for Roblox development.

## Build Commands

```bash
# Build the place file from source
rojo build -o "red-flag-ranger-roblox.rbxlx"

# Start development server (live-syncs changes to Roblox Studio)
rojo serve
```

## Architecture

The project uses Rojo's tree mapping (`default.project.json`) to map source files to Roblox's DataModel:

| Source Directory | Roblox Location | Access |
|------------------|-----------------|--------|
| `src/shared/` | `ReplicatedStorage.Shared` | Client & Server |
| `src/server/` | `ServerScriptService.Server` | Server only |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` | Client only |
| `tests/` | `ServerStorage.Tests` | Unit tests for pure logic: `print(require(game.ServerStorage.Tests)())` |

See README.md for the game architecture. Key rules:
- The world, NPCs, dogs and UI are all built in code at runtime (`WorldBuilder`, `DogRig`, `NPCService`, client controllers). There are no binary assets.
- Server services expose `init(services)` then `start()`; they reach each other through the shared `services` table (see `src/server/init.server.luau`).
- Dialogue and story content is data in `src/server/Content/`. All educational text is provisional pending Present Age review.
- Clients send ids only; every outcome is decided and validated on the server.

**Entry Points:**
- `src/server/init.server.luau` - Server-side entry point (runs on game servers)
- `src/client/init.client.luau` - Client-side entry point (runs on each player's client)
- `src/shared/*.luau` - Shared modules require'd by both client and server

**Security:** FilteringEnabled is active, enforcing client/server separation. Server-side code handles authoritative game logic; client-side code handles UI and local interactions.

## Rojo File Naming Conventions

- `*.server.luau` - Server scripts (execute in ServerScriptService context)
- `*.client.luau` - Client scripts (execute in player client context)
- `*.luau` - ModuleScripts (shared modules that must be require'd)
- `init.server.luau` / `init.client.luau` / `init.luau` - Directory entry points (the directory becomes the script)
