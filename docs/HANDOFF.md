# Handoff: interaction expansion, 2026-11-14 (session 3)

Read `CLAUDE.md`, then `docs/implementation-plan.md` (r3, Codex-approved; the source of truth for phases and decisions), then this.

## Rules from the owner

- Additive changes unless a requirement needs a new abstraction.
- Trail Walk and Wash & Groom are core, never cut. No deadline.
- Codex gives an independent read before planning and reviews every phase diff; fold its findings, then send the folds back for confirmation until APPROVE.
- "Question mode" = use the AskUserQuestion dialog for decisions.
- The spec overrides the research Storyline doc on purpose. Don't reopen those choices.
- Ask before stopping the owner's Studio Play session.
- Codex MCP is down; use the `codex:codex-rescue` agent with a read-only prompt and absolute paths.

## Branch state: `feat/interaction-expansion` (off `main` de6fa01; nothing pushed)

| Commit | What |
|---|---|
| e89edce | Plan r3 + `docs/research/` source docs |
| 5322a81 | Phase 0: save-lock, feedback-choice and stale-close fixes; agility runs are activity sessions; fetch interrupt frees the dog |
| b6f1ce0 | Phase 1: schema v3, `Data.checkpoint`/retried release, `InteractionState`, `PanelCoordinator` |
| eb05424 | Dialogue lifecycle: exit kinds, node revisions (`rev`), presented facts |
| 23257ee, 3d379b2 | `docs/campaign-script.md` (40 provisional scenes) + owner decisions on its notes |
| de1fce1 | Pure `EncounterScheduler`, `LearningProgress`, `ScoreRules`, `ContentCheck` + tests |
| 8148c6c | `ProgressionService`, campaign conditions, `Data.view` + privacy tests |
| 7a5664c, 3128079 | Phase 1 Codex folds (scheduler `kind`, one exit per scene, gap from end/dismissal, checkpoint writer loop, forced close, real active time) |

Phase 0 and Phase 1: **Codex APPROVE**. 138 tests pass in Studio; clean boot. Story invitations are intentionally OFF (`ProgressionService.INVITATIONS_ENABLED = false`) until Phase 2.

## Next step 1: integrate Track B (minigames), NOT yet on the branch

Built by an agent in worktree branch `worktree-agent-a196ee3313227a43a` (based on 5322a81), **never run**. Commits, in order: `f973cfc` (Trail/Groom/Ratings rules + tests), `ca20139` (Trail Walk, hands-on Wash & Groom, activity ratings), `c1d3460` (whistle/command confirm, client-side), `820fcff` (agility unlocked at adoption), `1c31e34` (README/CLAUDE.md).

- Cherry-pick them onto `feat/interaction-expansion`. Expected conflicts: `Remotes.luau` (PanelState vs TrailHold/TrailWalk kinds), `ProfileSchema.luau` (v3 types vs `bestRating`; keep v3, keep `bestRating: number?`), `client/init.client.luau`, `README.md`, `CLAUDE.md`.
- Then sync and run the tests (expect ~167). The agent's full manual Studio checklist (keyboard/mouse, touch, gamepad, whistle confirm, cancel paths) is in its report; the essentials: trail markers in order, squirrel hold ≥1.8 s inside 6 s, walk never fails, stars on completion; spa gestures per step, shake, stars; first whistle press during any activity asks, second cancels.
- Its own calls the owner may want to tune: shine base (2 stars if steps average ≤12 s), evenness ±1 star at ≥0.7/≤0.3, trail score 0.6 holds + 0.3 time vs par (60 s) + 0.1 sniffs. Not done: the "pick any activity" journal objective.
- Then a Codex review of the Track B diff, then the owner's feel playtest (Phase 3 verify list).

## Next step 2: Phase 2 (story vertical slice)

Per plan section 5. Transcribe from `docs/campaign-script.md`: onboarding (Lee welcome + disclosure, Cara intro), Cara talk 1, `park_e1_hello`, `green_riley`, `park_e2_deal` (all branches), `lee_tell`, recovery, block → `rp_e2_deal` roleplay, invitation card (Talk / Later / Skip this story). Also: Sparkz per-player matching dog visual, Jordan arc unscheduled, NPC visibility rule, dialogue "Story character" label, `help_lee` "another app" + "Did this happen in a park story?" (owner decision), Lee can open the practice menu. Export `facts` (with `concerning`) and encounter `beat`/`roleplayFor` from `Content/init.luau`; turn invitations on.

Owner decisions on the script (end of `docs/campaign-script.md`): Reach Out needs ≥1 fact picked; general Help asks if it was a park story; Cara stays blockable, Lee opens practice; Help mid-scene ends the scene.

## Studio notes

- Sync: `cd tools/studio-sync && python3 build_manifest.py ../.. manifest.json`, serve with `python3 -m http.server 34999 --bind 127.0.0.1`, stop Play, run `sync.luau` via MCP `execute_luau` (Edit).
- `execute_luau` in Server/Client runs in a separate require cache: you can't read live service state from it. Observe through remotes, pushes, attributes and console output.
- To test agility without fetch before Track B lands, patch `Content.Activities` Source in Edit mode; the next sync restores it.
- `DialogueChoose` is rate-limited to 0.15 s; space test requests ≥0.4 s apart.

## Open (not blocking)

- Who reviews the dialogue, and when: undecided.
- Solo vs shared servers: build shared-safe; decide at publish.
