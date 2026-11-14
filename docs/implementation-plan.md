# Implementation plan: interaction expansion

Status: DRAFT r3, for owner review. Codex reviewed r1 (REVISE, 9 findings) and r2 (7 of 9 resolved; REVISE on panel lifecycle, checkpoint release, grooming readiness, medal storage). r3 folds those in; each file claim was re-checked on `de6fa01`. **Codex: APPROVE on r3.** Awaiting owner review. Nothing is built yet.
Implements: `docs/interaction-expansion-spec.md` (the spec wins any conflict).
Inputs: the spec, `docs/research/*` (design inputs only), Codex's independent analysis (2026-11-14), owner answers.

## 1. Ground rules

- **Additive first.** New modules and new content beside the old. An existing module changes only where a requirement needs it; every such change is listed in section 4.
- **Minigames are core.** Trail Walk and Wash & Groom are how this feels like a real Roblox game. They get their own phase right after the story slice, not a polish slot at the end.
- **Base.** Both `feat/pet-interaction-phase-2` and `feat/dog-whistle` are merged; build on `main` at `de6fa01` or later, on a fresh branch `feat/interaction-expansion`. Line references below were re-checked on `de6fa01`. Help is already never hidden during petting there (`HUDController.luau:320`), so r1's change 11 was dropped.
- **Reviews.** Codex reviews this plan, then each phase's diff before the owner's Studio check.
- **Never:** publish, spend Robux, overwrite the open `.rbxlx`, award real badges, add Marketplace items. All educational copy stays `provisional`.

## 2. Decisions

### Owner decisions (2026-11-14)

| Topic | Decision |
|---|---|
| Trail Walk challenge | Follow paw markers along a public trail, and keep the leash steady when a squirrel distracts the dog (timing hold) |
| Wash & Groom | Keep the existing station and its 4 steps. Each step becomes a hands-on gesture. Result is a "shine" rating the Pet Show uses |
| Whistle or command during an activity | Cancels the activity, with a confirm on the first press |
| "Skip this story" | Skips the current scene only |
| Title cosmetics | **Visible to other players** (the spec said owner-only; owner chose visible). Sparkz's matching dog is still shown only to that player |
| Saves | Prototype, never deployed, no real players. Schema bump with default fill only; no legacy-learning migration work |
| Spec vs Storyline doc | The spec's overrides are intentional (no dog warnings, dismissible Carrie/Cara, no coins for safety choices, fixed 30-point model, equal adult treatment) |

### Defaults for spec gaps (Codex section D)

Owner confirmed (2026-11-14): healthy beat, active play, and grooming shine below; Trail Walk never fails; design shared-server-safe. The rest stand unless the owner objects.

| Gap | Default |
|---|---|
| Does "resolved" include skipped? | Yes. `resolved`, `skipped` and `skipped_by_block` all let the next beat become eligible |
| Healthy beat before E2 | An explicit campaign step `green_riley` between E1 and E2. Offered like a story invitation. Any answer, including "not now", satisfies it once the player has seen it |
| "Active play" for the 90 s gap | Seconds the player is in the game, their character is alive, and they have moved or acted in the last 30 s. Gap starts when the previous unsolicited scene ends or its invitation is dismissed. Remaining gap is saved |
| Review attempt | Starts when the first card of a set is answered. Leaving mid-set resumes the same set. `firstAttempt[slot]` is the first answer ever given for that slot. **Presentation is tracked separately from answering:** a bounded `presented[cardId]` set is written when a card is shown. Each answer is labelled `fresh` (first presentation, answered), `resumed` (presented earlier, answered after leaving) or `reused` (set seen in a previous rotation). Only `fresh` counts as transfer evidence in Studio evaluation |
| Roleplay credit | Cara roleplays record facts and evidence under the same milestone IDs as the beat they replace, so blocked or skipping players can reach full credit |
| "Actually shown" facts | Each node declares the facts it presents. Facts are recorded when the node is sent to the client. Tip/feedback text never adds facts |
| Title items | New items, never existing purchasable ones. Cosmetic only. Lee's line "a badge doesn't make anyone safe" stays. Because titles are visible (owner decision), the awarded title id and its cosmetic are the **only** learning-derived data allowed to replicate. Totals, evidence, answers and rules stay private, and the payload-privacy tests exempt exactly that one field |

## 3. New modules

| Module | Kind | Responsibility |
|---|---|---|
| `src/server/Logic/EncounterScheduler.luau` | Pure | Campaign state machine (`not_started → eligible → invited → active → resolved/deferred/skipped`), eligibility, priority (help > replay > recovery > campaign > ambient), active-time gap, defer and skip, block → `skipped_by_block`. Input: saved state, ordered validated events, busy flag, active seconds. Output: transitions plus one invitation decision. No clocks inside |
| `src/server/Logic/LearningProgress.luau` | Pure | Fixed evidence ledger (30 slots), `max(old, new)` updates, category totals, first-attempt vs best, `needsCoaching`, title predicates (Rookie/Cadet/Ranger). Consumes semantic events like `{ beat = "e2", kind = "left_after_request" }` |
| `src/server/Content/ScoreRules.luau` | Server data | Evidence slot ids, weights (all 1), thresholds, `rulesVersion`. Never in Shared |
| `src/server/Logic/ContentCheck.luau` | Pure | Graph checks the engine lacks: every node reachable, every branch ends or recovers, exits exist, fact ids known, review sets have 3 benign + 3 concerning slots |
| `src/server/Services/ProgressionService.luau` | Service | Wires activity completions, dialogue outcomes and active time into the scheduler and ledger. Serializes per-player updates (EventBus listeners run unordered). Pushes invitations. Claims titles and the ribbon. Optional badge adapter, off by default |
| `src/server/Services/InteractionState.luau` | Service | One "what is this player busy with" answer. The scheduler asks it before inviting. **Server-owned states**, set by their owners: activity (`ActivityService.begin/finish/interrupt`), dialogue including Lee's help scene (`EncounterService` session start/end), petting (`PetInteractionService` petting start/stop). **Client-owned panels**, reported through a new `PanelState` request kind: shop, journal (`MissionsController`), adoption (`AdoptionController.luau:60,72` opens and closes locally) and the HUD Help popup (`HUDController.luau:314`). A client signal can only *suppress* invitations, never authorize a reward or progression. While a client panel is open the client renews it every 30 s; the server drops it after 75 s without renewal. On respawn the client re-sends its current panel state rather than the server clearing it. `PlayerRemoving` clears everything |
| `src/client/Controllers/PanelCoordinator.luau` | Client | One active panel at a time. Hooks: `Shop.open/close`, `Missions.open/close`, `Adoption.open/close`, the HUD Help toggle, and a new public `Dialogue.close()` adapter that sends the existing close request (today dialogue closes only through its button and push handling, `DialogueController.luau:145,225`). Opening one panel closes the others and sends `PanelState`; renews and resyncs as above |
| `src/server/Activities/TrailWalk.luau` | Mechanic | Trail Walk server side (section 6) |
| `src/client/Controllers/TrailWalkController.luau` | Client | Markers, leash meter, hold input for all three input types |
| `src/client/Controllers/GroomingGestures.luau` | Client | Gesture input per grooming step, reusing petting stroke detection |
| `src/server/Content/Campaign/*.luau` | Content | Cara, E1–E5, Dash intro, healthy beats, Lee tell menu, recovery, roleplays, review sets A/B/C, Rookie Rescue, Listening Post. Aggregated by `Content/init.luau` |
| `src/client/Controllers/ShowController.luau` | Client | Pet Show stage, ribbon and title ceremony |
| `tests/*.spec.luau` | Tests | Scheduler, ledger, content checks, review sets, payload privacy, lifecycle |

Not built (Codex agrees): a minigame framework, a mission framework, a new pet rig, a new persistence layer, a pathfinding/escort framework.

## 4. Changes to existing code (not purely additive)

| # | Where | Change | Why it can't be additive |
|---|---|---|---|
| 1 | `PlayerDataService.luau:65` | On the last load attempt, refuse a live foreign lock instead of taking it over | Existing bug; reconnect safety depends on it |
| 2 | `EncounterService.luau:236` | Feedback mode accepts only the choice ids it displayed | Existing bug; any id finishes the scene |
| 3 | `EncounterService.luau:278` | A stale close only closes the session it names | Existing bug; can close a newer session |
| 4 | `EncounterService` lifecycle | One exit policy: left-before-concern, left-after-request, later, skip, help-preempt, block/report, interrupted (respawn, disconnect, activity). Help keeps the interrupted scene's context. Session id plus node revision on every request. Facts and outcome checkpointed in memory (and a durable save queued) before follow-up feedback shows | Silent replace and distance-close lose safe-exit credit |
| 5 | `Agility.luau` | Register runs with `Activity.begin/finish` | Otherwise the scheduler could invite mid-run |
| 6 | `Grooming.luau` | Unique run id, per-step milestones, readiness guard, shine result | Four timed requests can fake a run today |
| 7 | `StoryArcs` / scheduling | Jordan arc not scheduled while the new campaign is on. Definitions and Jordan as a peer stay | Spec: no two escalating stories |
| 8 | `PetService` + `AdoptionController` | Preset name ids, validated on the server. Free-text adoption path removed | Spec requirement |
| 9 | Agility unlock | Granted at adoption. The first-fetch quest still completes and fetch still pays its activity rewards; the quest's only reward (the agility unlock, `QuestCatalog.luau:47`) becomes a harmless repeat | Spec requirement |
| 10 | `EncounterService.luau:190` (Priya) | Priya can open a conversation as well as the shop | Her healthy gift beat |
| 12 | `WorldController.luau:128` | One visibility rule combines blocking and story presence | Toggling either alone can reveal a hidden NPC |
| 13 | `ProfileSchema` | v3: add `learningV2`, `campaign`, `show`, `review`, `titles`; default fill only | New saved state |
| 14 | `DialogueController` | "Story character" label, fixed choices, always-visible exit and help, practice-tool explanation, dismissible coaching | Spec UI rules |
| 15 | Whistle / commands (`PetInteractionService`) | During an activity, first press asks to confirm, second press cancels and the dog comes | Owner decision; must match the whistle branch once merged |
| 16 | `tests/PetSystems.spec.luau:117` | Schema version assertion updated; bond conversion assertions kept | v3 bump |
| 17 | `PlayerDataService` persistence | `saveProfile` returns whether a write was **committed** (false on a pcall error or when `UpdateAsync` is cancelled because another server holds the lock, `PlayerDataService.luau:91-110`). New public `Data.checkpoint(player, reason)`: the caller has already updated the in-memory profile, which is authoritative for this server session; `checkpoint` queues a durable save, coalesced to at most one write per player per 6 s and serialized with autosave and release. **Release contract:** on `PlayerRemoving`, cancel the pending timer and run the final release save, retrying up to 3 times with backoff before the entry is dropped (today the entry is removed right after one attempt, `:157-159`). `BindToClose` drains all pending saves. **Failure policy:** a failed save keeps the in-memory state, retries on the next autosave, never rolls back progress, and logs once. Feedback is never delayed waiting for a durable write. Ledger/scheduler updates are idempotent, so a replay after a lost save can't double credit | `saveProfile` is private and reports nothing; today only autosave and removal persist |
| 18 | `ActivityService.complete` + `ProfileSchema` | Accept an optional validated `rating` (1–3) in `data`, store `bestRating` in `profile.activities[id]` (added to the activity record type, `ProfileSchema.luau:44`), and include it in the `activity.completed` event | Shine and trail stars need a route to the Pet Show. Today the record persists only count and best time; the medal appears only in the event, and medal awards are stored separately as claims (`ActivityService.luau:117-123,143-145,165-169`) |
| 19 | `Encounters.luau:330` and other reachable legacy copy | Audit every reachable line; replace real platform names ("Snapchat, Discord") with "another app". Content ids unchanged | Spec line 21 |

### Integration wiring (narrow, additive registrations)

New modules only run once registered. These edits are small and listed so none is forgotten:

| Phase | Wiring |
|---|---|
| 1 | `init.server.luau`: add `InteractionState` and `Progression` to `services` and `order` after `Encounter`. New condition types in `Conditions.luau`. Snapshot additions (public unlocks, visible title, active invitation) in `PlayerDataService.snapshot`. `Remotes`: `PanelState` request kind, `Invitation` push kind. `client/init.client.luau`: register `PanelCoordinator`; add its hooks to Shop, Missions, Adoption, HUD Help and the new `Dialogue.close()` |
| 2, 4 | `NPCs.luau`: Cara, Sparkz_Pup, Dash, rookies with placements. `Content/init.luau`: aggregate `Campaign/*`. `NPCService` placements for new characters |
| 3 | `Content/Activities.luau`: `trail_walk` definition. `ActivityService` `MECHANICS` list adds `TrailWalk`. `WorldBuilder` + `shared/Places.luau`: trail loop, markers, trailhead. `client/init.client.luau`: register `TrailWalkController`, `GroomingGestures`. `ActivityController`: grooming spots route to the gesture input instead of the 4 buttons. Remote kinds for trail and grooming progress |
| 5 | `WorldBuilder`: show stage. `QuestCatalog`: journal objectives (pick any activity, reach the show, optional practice; no coin-tied help quests). `ItemCatalog`: title cosmetics. `client/init.client.luau`: `ShowController` |

## 5. Phases

Each phase ends with: all tests passing in Studio, a Codex review of the diff, then the owner's Studio check. No phase is called complete until its "Verify" list is observed.

### Phase 0: Baseline (after both merges)
- Branch off `main`. Run tests and record the count.
- Fix changes 1–3, each with a regression test.
- Agility joins activity sessions (change 5).
- **Verify:** tests green; a second concurrent "server" lock is refused in a unit test; stale close and bad feedback ids are rejected.

### Phase 1: Foundations
- Schema v3 (change 13), `Data.checkpoint` (17), wiring for phase 1.
- `EncounterScheduler`, `LearningProgress`, `ScoreRules`, `ContentCheck`, `InteractionState` + `PanelCoordinator`, `ProgressionService` skeleton.
- Dialogue lifecycle policy (change 4).
- Ledger stores only fixed slots, bounded `seenFacts`, bounded `needsCoaching` (cleared by recovery, replay success or contextual support) and bounded review state. No transcripts, no unbounded attempt lists, no lifelong risky-choice count. Titles, once awarded, are never revoked.
- **Verify:**
  - Scheduler table tests: skip, defer, block, unblock, reconnect, busy, no bursts.
  - Ledger tests: cap 30; recovery equals initial success; generic Help earns nothing; retries can't exceed caps; direct Lee and Cara-then-Lee each cap at 2 per beat; `needsCoaching` clears and never gates.
  - Default fill keeps every existing field and creates no learning credit (spec 202).
  - Privacy test walks snapshots, dialogue payloads, every push kind and every module under `ReplicatedStorage`: no scores, rules, answer keys, unseen answers or evidence (spec 213). Only the visible title id is exempt.
  - Checkpoint tests: coalescing, serialization with autosave, simulated save failure keeps state and retries.

### Phase 2: Story vertical slice
- Lee's welcome and the practice-story disclosure (player moving within about 30 s).
- Cara: intro and her first ordinary conversation.
- E1, `green_riley`, E2, every branch authored.
- Lee's tell menu built from seen facts, including "I'm not sure", "I agreed at first", "That's all I want to say".
- Cara's "Let's talk to Lee together" waypoint, with remote help always available.
- Recovery and replay. Block Sparkz → `skipped_by_block`, then the Cara roleplay for E2.
- Sparkz's matching-breed dog shown only to that player (a `DogRig` visual, not a registered pet).
- Jordan unscheduled (7), visibility rule (12), dialogue UI (14), legacy copy audit (19).
- Every encounter carries full metadata (stable id, content version, NPC id, prerequisites, facts, choice ids, outcomes, safe exits, recovery, review status, skill mapping). Each scene targets 30–60 s with at most one follow-up card. Blocking a benign character is allowed and earns no points and no scolding.
- **Verify (automated):**
  - Same activity and choice sequence gives the same encounter sequence; fetch counts completed rounds, not throws (spec 203).
  - A benign or premature leave records no threat evidence and costs no ordinary reward (208).
  - Lee's menu lists only facts actually presented; "That's all I want to say" exits at any point (211).
  - Every exit route (distance, close, Help, respawn, disconnect, block) for E1, `green_riley` and E2: no duplicate rewards or credit, campaign never stranded (215).
  - `ContentCheck` run against the real content: unknown actions/conditions, unreachable nodes and dead ends fail (216).
- **Verify in Studio:** safe exit, mistake then recovery, immediate leave after the concerning ask (full Respond credit), early block, all-skips, replay, Help mid-scene then back. Open and close the shop and adoption with an invitation pending: no invitation while open, invitation can arrive after close. Respawn with a pending invitation (204).

### Phase 3: Minigames (section 6)
- Trail Walk end to end. Wash & Groom gestures and shine (change 6). Activity ratings (18). Whistle confirm-cancel (15). Agility at adoption (9). Wiring for phase 3. Journal objective "pick any activity".
- **Verify (automated):** for both minigames: stale run id, duplicate step, too-fast step, step before readiness, result after cancel, and a second completion of the same run are all rejected; completion pays exactly once.
- **Verify in Studio with the owner:** each activity on keyboard/mouse, touch emulation and gamepad. Cancel by whistle, respawn mid-run, repeat completions count as rounds. A story invitation never appears mid-run (204). Every cue (squirrel, leash meter, suds) has a visual shape or text, not color or sound alone (219). The success metric is feel: satisfying to repeat.

### Phase 4: Full campaign
- E3, E4, the Dash intro (first agility visit, or the bench fallback) and E5.
- Remaining healthy beats: Priya's no-strings gift (10), Cara accepts "later", Coach Sam praises effort.
- Cara's other two ordinary conversations. Cara roleplays for E3–E5.
- Reconnect and interruption safety for every scene.
- Same metadata, 30–60 s and one-follow-up rules as Phase 2.
- **Verify:** block in E2 means no direct E3/E4 contact, show **eligibility** (the predicate; the stage is Phase 5) stays true, and roleplays can earn all missing evidence. E5 reassures the player and never gates show eligibility. Exit-route matrix (215) and `ContentCheck` (216) extended to E3–E5, Dash and all roleplays.

### Phase 5: Completion
- Pet Show stage after 4 activities (any mix). Every dog gets a positive category drawn from fetch, agility time, grooming shine and trail stars. Universal Rookie ribbon.
- Review sets A (Storyline's six), B and C: 18 cards, rotating by attempt; reused sets are labelled practice.
- Titles: ceremony, pledge, visible cosmetic items.
- Rookie Rescue (3 NPC cases), Listening Post.
- Review shows no hints before an answer and gives feedback after.
- Preset names (8). Badge adapter, disabled with no ids; local title claims are separate from badge delivery, which retries without re-granting local rewards.
- Wiring for phase 5, including journal objectives for the show and optional practice.
- **Verify:**
  - Cadet and Ranger reachable by both the first-try and the recovered paths; every earning route is open before any title (212); the 30-point cap holds.
  - A player who declines every story still gets the show and ribbon; actual show entry works for a player who blocked Sparkz in E2.
  - Same attempts give the same review rotation (203); each set has six matched slots, 3 benign + 3 concerning; `fresh`/`resumed`/`reused` labels are correct (217).
  - Badge adapter: no ids means no request; a failed call doesn't block local progress; a retry doesn't duplicate local rewards (218).

### Phase 6: Delivery
- Reviewer packet (every node, choice, outcome, concern, safe alternative, feedback).
- Adult guide draft (no legal duties or hotline numbers copied unverified).
- README update and a coverage checklist against spec section 11.
- Two-client Studio test: different story stages; one player's block, invitation, show progress and title state don't change the other's; the other player sees the title cosmetic and nothing else learning-related (214).
- Input pass: on phone, mouse/keyboard and gamepad, a player can read choices, exit, reach Help and complete every activity (219).
- **Report:** implemented, automated checks, observed in Studio, still unverified, release prerequisites, deviations.

## 6. Minigame designs (drafts for owner markup)

### Trail Walk
- **Place:** a looped public trail around the park edge, always in view of other areas. A plain fence runs along part of it as scenery; nothing is built beyond it.
- **Loop:** clip the leash on at the trailhead. Walk past 8–10 glowing paw markers in order. Sniff spots give small bonuses.
- **Challenge:** 2–3 times per walk a squirrel darts out and the dog lunges. A leash meter appears; hold the button (or key) to keep the needle in the green band for about 2 seconds. Success: the dog settles with a happy reaction. Miss: the dog tugs a few studs off the path and comes back; the walk never fails.
- **Result:** 1–3 trail stars from markers in order, steady holds and time.
- **Server checks:** one run id per walk. Markers are reached in order, by server-checked position, each no faster than a minimum time, each counted once. The server schedules each squirrel moment with its own challenge id. The client sends `holdStart` and `holdEnd`; the server measures the hold itself (must be ≥ 1.8 s and end inside the window); each challenge accepts one result. Cancelling cleans up the leash and markers and voids the run. Stars are computed on the server from those validated facts.
- **Inputs:** hold LMB/Space, a large on-screen hold button on touch, R2/A on gamepad.

### Wash & Groom (extend the existing salon)
- **Brush:** drag strokes along the dog's back, reusing the petting stroke detection. Fur fluffs.
- **Wash:** scrub in circles to fill a suds meter. Bubbles build up.
- **Rinse:** sweep across the dog; suds clear where you sweep.
- **Dry:** hold to run the dryer; the dog shakes at the end.
- **Result:** a 1–3 star shine. The existing sparkle effect stays; the shine feeds the Pet Show.
- **Server checks:** one run id; steps in order; each step reports 25/50/75/100% milestones, each once, no faster than a minimum time; proximity as today, plus a **new** server readiness flag set once the dog is in the tub (today's step handler checks session, order, elapsed time and proximity, but not readiness, `Grooming.luau:74-101`). Gesture detail (stroke evenness) is a **client estimate**: the client sends an evenness value per step, the server clamps it to 0–1 and lets it move the shine by at most one star. Time per step, measured by the server, sets the base. Full server reconstruction of gestures is deliberately not attempted; the shine is cosmetic.
- **Inputs:** mouse drag, touch drag, gamepad stick plus a button.

## 7. Risks

| Risk | Mitigation |
|---|---|
| Overlap with the merged whistle and dog work, and the planned tap-the-dog ring and solid dog | Whistle `come` interrupts activities directly today (`PetInteractionService.luau:248,260`); change 15 adds the confirm there. Re-read `PetService`/`PetController` before Phase 3 in case the ring or solid-dog work lands first |
| Story timing isn't reproducible because it depends on active time | Determinism means: same start state, same ordered events and same active seconds give the same decisions. Tested that way |
| Scheduler and ledger state out of sync after a disconnect | Checkpoint in memory at every transition, durable within about 6 s, final release save with retries (change 17). Idempotent event application |
| Large amount of child-safety copy, all provisional | Reviewer packet in Phase 6; every content item tagged `provisional` with a version |
| Visible title cosmetics could look like a trust badge | Owner decision. Cosmetic only, no moderation powers, Lee's badge warning stays. Flag for the reviewer |
| Studio-only test runner | Keep logic pure and well covered; Studio checks for physics, UI and two clients |

## 8. Open items (none block Phase 0)

- Who reviews the dialogue, and when they first see it: **not decided** (owner, 2026-11-14). Doesn't block building.
- Solo vs shared servers: build shared-server-safe (owner, 2026-11-14); server size is a publish-time decision. No live server settings change in this plan.
