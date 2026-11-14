# Handoff: interaction expansion, 2026-11-14 (session 4)

Read `CLAUDE.md`, then `docs/implementation-plan.md` (r3, Codex-approved; source of truth for phases and decisions), then this, then `docs/phase2-notes.md`.

## Session 5 (2026-11-14): Phase 2 verified, PR open

- Branch pushed as `feat/interaction-expansion`; **draft PR #14** into `main`. `main` (frisbee field, jump obstacles, roblox skill) merged in at 41e72dd.
- Tests 275/275. Codex Phase 2 review APPROVE after 4 rounds. Track B checklist and the whole Phase 2 Studio checklist pass (results and found issues in `docs/phase2-notes.md`).
- Fixed in Studio: ContentCheck brace, Codex folds, story card closes when an activity starts, Sparkz moved away from the squeaky duck (its prompt stole E).
- Open, small: Rinse 💧 and the Help popup's close button render as empty boxes; Riley's card has no label; Lee-narrated roleplay lines mention asking Lee; spa via Hold Space is an easy 3 stars; the real Space-key squirrel hold is unconfirmed by hand.
- Studio MCP: if tools vanish, stale `StudioMCP` processes from other sessions hold the connection; ending them (owner approved) restored it. Codex MCP was down; `~/.local/bin/codex exec -s read-only` works directly.
- Next: owner's feel playtest (Track B) and Studio check (Phase 2); then Phase 3 leftovers and Phase 4.

## Rules from the owner

- Additive changes unless a requirement needs a new abstraction.
- Trail Walk and Wash & Groom are core, never cut. No deadline.
- Codex reviews every phase diff; fold its findings and resend until APPROVE. Codex MCP is down: use the `codex:codex-rescue` agent with a READ-ONLY prompt and absolute paths.
- "Question mode" = AskUserQuestion. The spec overrides the research Storyline doc on purpose.
- Ask before stopping the owner's Studio Play session. Never push without the owner's word.
- Worktree agents start from `main`: tell them to `git reset --hard` onto the integration branch first, and never let them use Studio (one shared Studio; the orchestrator serializes tests).
- Another session ("Red Flag Rangers dog controls") is building the tap-the-dog ring and solid dog off `main` (PetService, PetController, ActionBarController). Ping it before touching those.

## Branch state

Work is on **`worktree-trackb-integrate`** (worktree `.claude/worktrees/trackb-integrate`), which is `feat/interaction-expansion` (90e7112) plus:

| Commit | What | Status |
|---|---|---|
| 8bf0081..3fddcd7 (already on feat/interaction-expansion) | Track B: Trail Walk, Wash & Groom gestures, ratings, whistle confirm, agility at adoption | 167 tests passed in Studio |
| 59039f9 | Track B Codex folds: grooming pays at completion + token-guarded cleanup; queued squirrel moments; death/respawn interrupts any activity (`ActivityService`) | **Codex APPROVE**, not yet run |
| 77303b7..434a1d6 (8 commits) | Phase 2 story slice (see `docs/phase2-notes.md`) | **Never run, not reviewed** |

`feat/interaction-expansion` has NOT been moved. Once tests pass, fast-forward it to `worktree-trackb-integrate`. Nothing is pushed.

## Next, in order

1. **Studio**: the MCP connection broke in session 4 and `/mcp` reconnect didn't restore the tools; a fresh session should. Sync (below), run tests (expect ~248). Fix failures (Phase 2 code was written without a Luau toolchain, so syntax/type errors are likely).
2. Clean boot in Play; check console.
3. Track B manual checklist: trail markers in order, squirrel hold ≥1.8 s inside 6 s, walk never fails, stars; spa gestures per step, shake, stars; first whistle press during an activity asks, second cancels; dying mid-activity ends it cleanly.
4. Codex review of the Phase 2 diff (`git diff 59039f9 434a1d6`), fold until APPROVE.
5. Phase 2 Studio checklist (`docs/phase2-notes.md`), then the owner's feel playtest (Track B) and Studio check (Phase 2).
6. Then Phase 3 leftovers (journal objective "pick any activity") and Phase 4 per the plan.

## Studio notes

- Sync: `cd tools/studio-sync && python3 build_manifest.py ../.. manifest.json`, serve with `python3 -m http.server 34999 --bind 127.0.0.1` (from that folder in the worktree), stop Play, run the body of `sync.luau` via MCP `execute_luau` (Edit).
- `execute_luau` in Server/Client runs in a separate require cache: observe through remotes, pushes, attributes and console output.
- `DialogueChoose` is rate-limited to 0.15 s; space test requests ≥0.4 s apart.
- Starting Play via MCP `start_stop_play` hung the MCP connection in session 4. If it happens again, ask the owner to start Play by hand.

## Open (not blocking)

- Who reviews the dialogue, and when: undecided.
- Solo vs shared servers: build shared-safe; decide at publish.
- Owner may want to tune Track B scoring: shine base (2 stars if steps average ≤12 s), evenness ±1 star at ≥0.7/≤0.3, trail score 0.6 holds + 0.3 time vs par (60 s) + 0.1 sniffs.

## From main: jumping obstacles (merged 2026-11-14, PR #11)

- **Player:** benches, fences and hurdles were already collidable but low enough to step over. `WorldBuilder` now adds invisible `PlayerBlocker` walls (3.2 to 3.4 studs, collision group `PlayerBlocker`, collides with `Characters` only), so the player has to jump them.
- **Dog:** the visible parts are tagged `JumpObstacle`. `PetController` lifts the dog's body over them using `Shared/ObstacleHop` (animation only: the root stays on the ground, on every client). Ground and aim raycasts exclude both tags, so the follow target no longer climbs onto benches and rails.
- **Not played yet.** The code was written without a Studio session; only `rojo build` was run. Check: `ObstacleHop.spec` passes; you are stopped by and can jump each obstacle; the dog hops when crossing and not when running alongside a fence; the fetch ball ignores blockers; agility medal times still feel fair now that hurdles need a jump; touch auto-jump on blockers.
- **Dog sinking when you jump:** the follow target rides your character during the physics step, so the dog rose with a jump and dipped under the floor on the way down. `PetController.keepOnGround` now puts a Following/Returning dog back on the ground under its own feet after every physics step (owner client only). Not played yet.
- A hand-built `Workspace.World` needs its own tags and blockers. Trees, lamp posts, weave poles and buildings are unchanged (the dog still passes through them).

