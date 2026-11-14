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

**No Rojo?** `tools/studio-sync/` pushes the source into an open Studio session through the Roblox Studio MCP server (see its README): build `manifest.json`, serve it on `localhost:34999`, stop Play, then run `sync.luau` with the MCP `execute_luau` tool in the Edit datamodel. It rebuilds the four mapped trees and runs the tests. It does **not** apply `default.project.json` `$properties` (Lighting, etc.); set those by hand in Studio.

**Testing:** run `print(require(game.ServerStorage.Tests)())` in Studio (Edit mode works). Pure logic lives in `src/server/Logic/` and `src/shared/` so it can be tested without a running game. The place is unpublished, so DataStores don't work and the HUD shows "Not saving"; profiles reset every session.

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
- Dialogue and story content is data in `src/server/Content/` (practice-story scenes in `Content/Campaign/`, transcribed from `docs/campaign-script.md`; field reference at the top of `Campaign/Sparkz.luau`). All educational text is provisional pending Present Age review.
- Clients send ids only; every outcome is decided and validated on the server.

**Entry Points:**
- `src/server/init.server.luau` - Server-side entry point (runs on game servers)
- `src/client/init.client.luau` - Client-side entry point (runs on each player's client)
- `src/shared/*.luau` - Shared modules require'd by both client and server

**Security:** FilteringEnabled is active, enforcing client/server separation. Server-side code handles authoritative game logic; client-side code handles UI and local interactions.

## The dog (read before touching pet code)

- **Movement:** every dog part is `CanCollide = false`; the dog floats on one `AlignPosition` toward an attachment (`PetService`). Its physics are simulated on the **owner's client**, so client code (e.g. `WorldController`'s world wrap, `BallController`'s chase point) may move it directly.
- **Behavior is a state machine:** `src/server/Logic/PetStateMachine.luau` defines the states (Following, Sitting, Fetching, ...) and allowed transitions; change state only through `PetService.setState`, which returns a token activities use to check they're still in charge. `PetService.react(player, mood)` sets a short flourish (`Mood`/`MoodAt` attributes) that `PetController` animates on every client.
- **Recovery:** a Following dog more than 45 studs away is teleported back (200 studs for 6 s after a whistle, so it runs instead). A dog left Sitting/Staying more than 140 studs away is recalled.
- **Actions:** clients send `PetAction { action = ... }`; `PetInteractionService` validates against `PetActions` (touch distance, cooldown, bond unlocks) before running a handler.
- **Must stay true:** the dog runs on the ground and never flies. Fetch chases a ground point under the ball, not the ball.

## Practice stories (read before touching dialogue or campaign code)

- **Flow:** `ProgressionService` feeds server events into `Logic/EncounterScheduler` (which beat may come next) and `Logic/LearningProgress` (the private 30-slot ledger). Each tick `Progression.consider` asks for at most one invitation (never while `InteractionState.busy`, only beats in `Content.beatScenes`); `StoryService` shows the card and runs onboarding, Cara's follow-up offer, the walk to Lee, and story presence.
- **Scenes:** `EncounterService` sessions are `scene`, `card` (invitation / follow-up) or `tell` (Lee's menu, `Logic/LeeTell`). Every node sends a `bar` from `Logic/StoryRules.barFor`; the client renders only what the server lists. Facts are recorded when their node is sent; evidence comes only from `learning` actions and `ProgressionRules.exitEvents`, never from text.
- **Must stay true:** campaign scenes grant no coins; agreements go to a `recovery` node and never play out; Lee's menu lists only facts on file and `done` is on every node; Help after a concerning request ends the scene and opens Lee for that beat; nothing learning-related replicates (the snapshot only gets `present`, npc id -> boolean). `ContentCheck` (run in tests over the real content) enforces scene metadata.
- **Jordan:** his arc is `scheduled = false` while the campaign runs; he stays an ordinary peer.
- **Testing in Studio:** about 2 s after adopting (or loading with a dog and no onboarding), Lee's welcome opens by radio, then Cara's intro; close or answer them before testing anything else. Invitations need an activity completed after onboarding and 90 s of active play between them.

## Gotchas

- **Raycasts:** `CanQuery = false` is ignored on parts that collide, so exclude such parts (e.g. the fetch ball) explicitly with `RaycastParams`.
- **Collision groups** `FetchBall` and `Characters` already exist; reuse them rather than adding ad-hoc `CanCollide` toggles.
- **Lighting:** scripts (including MCP `execute_luau`) cannot read or write `Lighting.Technology`. Currently `Voxel`, and no object casts a visible ground shadow under it; a lighting change is being handled separately.
- **Sounds:** only built-in `rbxasset://sounds/...` are used (`src/client/UI/Sounds.luau`); custom asset ids go in its `CUSTOM` table.
- **Studio MCP testing:** `screen_capture` works in Play mode; `user_mouse_input` x/y are GUI coordinates (viewport minus the 58 px top inset); `instance_path` clicks need unique names. Adopt a dog in tests with `ReplicatedStorage.Remotes.Request:InvokeServer("adopt", { breedId = "golden", name = "Sparky" })` from the Client datamodel. Short-lived effects (the 1 s "!" bubble) are easier to verify by inspecting instances than by screenshot.

## Controls (current)

- **Whistle:** H / gamepad D-pad Up / the 📣 button (above the jump button on touch) calls the dog back from anywhere (`WhistleController`). During an activity the first press (whistle or Sit/Stay/Come) shows a "Stop <activity>? Press again" confirm (client-side, from the player's `ActivityName` attribute that `ActivityService` sets); the server is unchanged.
- **Action bar** (bottom-left, `ActionBarController`): Q / gamepad Y. Planned to be replaced by a tap-the-dog ring menu.
- Planned: the dog becomes solid to players and obstacles, sidesteps when walked into, and jumps agility hurdles.

## Docs

- `README.md`: game architecture and systems.
- `docs/interaction-expansion-spec.md` + `docs/developer-handoff.md`: the next large feature spec (encounters, Pet Show, Trail Walk, Wash & Groom).
- `docs/implementation-plan.md` (phases) + `docs/campaign-script.md` (every scene's text; owner decisions at the end).
- `docs/HANDOFF.md`: latest session handoff notes.

## Rojo File Naming Conventions

- `*.server.luau` - Server scripts (execute in ServerScriptService context)
- `*.client.luau` - Client scripts (execute in player client context)
- `*.luau` - ModuleScripts (shared modules that must be require'd)
- `init.server.luau` / `init.client.luau` / `init.luau` - Directory entry points (the directory becomes the script)
