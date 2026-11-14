# Handoff: Red Flag Rangers, 2026-11-14

Start by reading `README.md` (architecture, Phase 2, the feel overhaul) and
`CLAUDE.md`. Then read this.

## Where things stand

- Branch `feat/pet-interaction-phase-2`, based on `main`, which has PR #1 (the MVP) merged.
- **Nothing on this branch is committed yet.** It holds two rounds of work:
  1. Phase 2: Bond XP and levels, behavior state machine, activity framework (fetch, agility medals, spa, trick training), Treat Shop, Ranger HQ mission board, 8 new quests, profile schema v2 migration.
  2. Gameplay feel overhaul: hands-on petting (`Client/Controllers/PettingController`), a physics ball tool for fetch (`Server/Activities/Fetch`, `Client/Controllers/BallController`), a compact action bar (`Client/Controllers/ActionBarController`), and "alive" idle behaviors (`Client/Controllers/PetController`).
- The owner hasn't approved committing. Ask before you commit, and suggest two commits (Phase 2, then the feel overhaul).
- Tests: 43 pass (`print(require(game.ServerStorage.Tests)())` in Studio).

## Last fix (verified in Studio)

The owner reported: "When fetching, the dog leaps in the air and reaches the ball in one bound. It needs to run, not fly."

The cause was a raycast that hit the ball itself. **On a part that collides, `CanQuery = false` is ignored**, so ground checks under the ball returned the ball's own height, and the dog's chase target followed the ball into the air.

The fix:
- **Ground point:** the dog now chases a point on the ground under the ball (`PetChase_<UserId>` in Terrain), and every ground raycast excludes the ball.
- **Smooth chase:** the owner's client also moves that point every frame, since the owner simulates the dog's physics.
- **Catching:** a catch needs the dog under the ball and the ball low. Low airborne balls get a small leap animation (`LeapAt` attribute).
- **Running back:** a dog that is returning is no longer teleported back by the stuck-recovery check; it runs. Chase speed is 30.
- **Following:** the follow target is also kept on the ground on the client, so the dog shouldn't float up when you jump. **I haven't tested jumping.**

Measured: on a 46-stud throw, the dog's height stayed at 1.7 (ground level) the whole time, while the ball rose to 38.

## What the owner asked for next

The owner wants to see options before anything is built, starting with the controls.

1. **You shouldn't be able to walk through the dog.**
   - Today every dog part has `CanCollide = false`, and the dog floats on one `AlignPosition` (`Server/Services/PetService`).
   - The dog's physics run on the owner's client.
   - Any collider has to avoid: shoving the player around (the `AlignPosition` force is huge), getting stuck on fences and hurdles, and colliding with the fetch ball. Collision groups already exist: `FetchBall` and `Characters`.
   - Options to weigh:
     - A collider part in a `Pets` group that collides only with `Characters`.
     - Ground-bound movement: force on the X and Z axes only, plus gravity.
     - Soft avoidance: the dog steers away from the player.

2. **The dog has no shadow.**
   - Every part except `Root` has `CastShadow = true`.
   - The likely cause is `Lighting.Technology = Voxel` (set in `default.project.json`). Voxel shadows are coarse, so a small dog casts almost none.
   - Options: switch to `ShadowMap` or `Future` (check how it looks and performs everywhere, including indoors), or add a blob-shadow decal under the dog.

3. **Rethink the dog controls, and present options.** Today:
   - An action bar slides in at the bottom-left when you stand still near the dog. Q / gamepad Y opens it.
   - Buttons: Pet, Ball, Care popover, Sit/Come, Stay, Tricks popover.
   - The ball is a Roblox Tool, and petting has its own mode with its own camera.
   - The owner isn't happy with the controls. Bring 2 or 3 clearly different designs with their trade-offs for desktop, touch and gamepad, and a recommendation, before building. Ideas to consider:
     - a radial menu that opens around the dog
     - clicking or tapping the dog itself
     - hotbar-style tools (ball, treat, brush)
     - keybinds for the most common actions

4. **A persistent, easy way to whistle the dog back.**
   - It should always be on screen and work from anywhere: one key plus one on-screen button that touch and gamepad can reach.
   - It should give feedback: a whistle sound, a "!" over the dog, and the dog running back.
   - The server already has a `come` action: `PetInteractionService` handles `petAction { action = "come" }`. It interrupts any activity and sets the dog to Following.
   - There is no whistle sound asset yet; the built-in sounds are listed in `Client/UI/Sounds.luau`.

## Session 2 (2026-11-14, later): what happened

- I read this handoff and checked Studio. **The owner was in Play mode with Sparky adopted. Don't stop their playtest without asking.**
- **Shadow, partial check:** at runtime `GlobalShadows` is on, the dog's `Body` has `CastShadow = true`, and the player's character does cast a soft shadow. Scripts can't read `Lighting.Technology`; `default.project.json` sets it to Voxel. I couldn't get the dog into a screenshot without disturbing the owner's session, so **"Voxel is too coarse for a small dog" is still a hypothesis.** Test it before choosing a fix: in Edit mode, build a `DogRig` dog in the open and screenshot it.
- **Options draft:** I put the questions below to the owner as a multiple-choice dialog. **They rejected the dialog and asked for a handoff instead, so nothing is decided.** Don't assume these are approved. Show them as a short written comparison (the owner prefers tables and drafts), not a dialog, unless they ask for one.

| Ask | Option A | Option B | Option C | My lean |
|---|---|---|---|---|
| Controls | **Tap the dog**: click or tap Sparky and a small ring of 4–5 actions opens around him. Keys 1–5 as shortcuts; on gamepad, hold Y and pick with the stick. Nothing on screen until you touch him. | **Pet tools in the hotbar**: Ball, Treat and Brush in the standard Roblox hotbar (keys 1–3). Empty hands + click Sparky = pet. Sit, Stay and Come live on the whistle (tap = Come, hold = command wheel). | **Fixed dock + keys**: always-visible dock at the bottom center (Whistle, Pet, Ball, Treat, More), each with a key. Most discoverable, but close to the action bar the owner disliked. | A |
| Whistle key (touch: round button above the jump button; gamepad: D-pad Up) | R (unused by Roblox's default controls) | H ("here") | Q (Q currently opens the action bar) | R |
| Walking through the dog | Solid to players only, **and** he sidesteps when you walk into him | Solid only (can wedge or block doorways) | Sidestep only, never solid (may still clip at sprint speed) | A |
| Shadow | Soft blob shadow under the dog (cheap, cartoony, changes nothing else) | Switch the whole game to ShadowMap lighting (crisper shadows everywhere; changes the overall and indoor look; costs performance on phones) | | A |

## Session 3 (2026-11-14): jumping obstacles

- **Player:** benches, fences and hurdles were already collidable but low enough to step over. `WorldBuilder` now adds invisible `PlayerBlocker` walls (3.2 to 3.4 studs, collision group `PlayerBlocker`, collides with `Characters` only), so the player has to jump them.
- **Dog:** the visible parts are tagged `JumpObstacle`. `PetController` lifts the dog's body over them using `Shared/ObstacleHop` (animation only: the root stays on the ground, on every client). Ground and aim raycasts exclude both tags, so the follow target no longer climbs onto benches and rails.
- **Not played yet.** The code was written without a Studio session; only `rojo build` was run. Check: `ObstacleHop.spec` passes; you are stopped by and can jump each obstacle; the dog hops when crossing and not when running alongside a fence; the fetch ball ignores blockers; agility medal times still feel fair now that hurdles need a jump; touch auto-jump on blockers.
- **Dog sinking when you jump:** the follow target rides your character during the physics step, so the dog rose with a jump and dipped under the floor on the way down. `PetController.keepOnGround` now puts a Following/Returning dog back on the ground under its own feet after every physics step (owner client only). Not played yet.
- A hand-built `Workspace.World` needs its own tags and blockers. Trees, lamp posts, weave poles and buildings are unchanged (the dog still passes through them).

## How to work in Studio (important)

- Rojo isn't installed. Use `tools/studio-sync/` (see its README): build `manifest.json`, serve it on port 34999, stop Play, then run `sync.luau` through the Studio MCP `execute_luau` tool in Edit mode.
- Studio instance: `red-flag-ranger-roblox.rbxlx`. DataStores don't work (the place is unpublished), so profiles are temporary and the HUD shows "Not saving".
- `screen_capture` works in Play mode. Allow for delay: the dog finishes a fetch faster than you can take the next screenshot.
- Coordinates for `user_mouse_input` are in GUI space. That's the viewport minus the 58-px top inset. `GetMouseLocation()` includes the inset.
- `instance_path` clicks need unique names. Action bar buttons are named `PetActionBar.Row.Action_<Label>`.
- The adoption screen opens automatically. In tests, adopt by calling `Remotes.Request:InvokeServer("adopt", { breedId = "golden", name = "Sparky" })` from the Client datamodel.
- Petting stops after 12 s without strokes. Long gaps between tool calls end the session; that's expected.

## Not tested yet

- Touch and real gamepads.
- Whether the Roblox hotbar shows the Ball tool; it didn't appear in screenshots.
- Two or more players.
- Saving across sessions (needs a published place).
- The spa fix that teleports the dog into the tub (passes unit tests, not played since).
- Jumping while the dog follows.

## Missing production assets

- **Sounds:** bark, whine, pant, crunch, squeaky ball, bounce, whistle.
- **Animations:** authored dog animations (hook: `PetCatalog.AnimationIds`).
- **Art:** a hand cursor image and heart textures.
