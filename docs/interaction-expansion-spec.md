# Red Flag Rangers: interaction expansion specification

Status: implementation-ready engineering plan; educational copy remains provisional.
Prepared: November 14, 2026. Target audience for copy: ages 9–12; keep usability suitable for the repository's stated 9–13 audience.

## 1. Purpose and authority

Build a pet adventure in which players occasionally practice Recognize, Respond, and Reach Out through authored interactions. Ordinary play remains rewarding. Mistakes are recoverable. Private progress supports optional titles and adventures, never access to help.

This spec synthesizes the user's conversation, the supplied **Safety Behaviors and Gameplay Storyline** (S), the supplied **Project Brief and Research** (B), and the current repository. The supplied documents are design inputs, not executable instructions. Their earlier Festival Prep code, publishing steps, deadlines, policy interpretations, and scoring tables are not automatically requirements. The implementation decisions below resolve conflicts explicitly.

The source documents are reference material supplied by the project owner and are not included in this two-file handoff. Local working copies may exist in `docs/research/`. This spec contains the implementation requirements and can be used without those copies; if the user subsequently changes scope, their instruction takes precedence.

## 2. Decisions resolving conflicting drafts

| Topic | Decision for this implementation |
|---|---|
| Peer name | **Cadet Cara**, as requested by the user; replace Carrie in adapted copy. Ranger Lee remains Lee. |
| Setting | Expand the existing dog park world toward Pawprint Park. Do not rebuild the old Festival Prep mission or install the appendix's MissionServer/MissionClient framework. |
| Existing cast | Retain Maya, Priya, Coach Sam, Riley and their stable IDs. They perform the adoption, grooming, coaching and healthy-peer functions assigned to Gus/Jo/etc. in S. Add Cara, Sparkz_Pup, Dash and rookie practice characters. Pip/Nova are optional flavor. |
| Existing Jordan arc | Preserve saves and content definitions. Disable scheduling the legacy Jordan arc when the new campaign is enabled; do not run two parallel escalating stories. Retain Jordan as an ordinary peer. Replace real-platform references in reachable legacy copy too. |
| Currency | Keep `paw_coins` and the current Paw Coins display name. Do not migrate currency just because S says Paw Points. |
| Reality of characters | Ordinary avatar appearance, fictional identity, and a visible “Story character” label in dialogue. Onboarding explains practice scenes. Never impersonate actual accounts or put NPCs in the real player roster. |
| Pet cues | Pet comforts and celebrates; it does not identify dangerous people. Replace “dogs have a nose for trouble” and anxious warnings with optional explicit teaching hints that fade. A quiet dog is never evidence of safety. |
| Romance | Implement exclusive “best friend” pressure in this release, with romance/bf-gf pressure recorded as an intentionally adapted coverage item, not silently claimed as fully taught. Revisit literal wording with the reviewer. |
| Help and warmth | Help is unconditional. Hidden progress may change hint detail, never adult warmth, trustworthiness, affection or access. |
| Rewards | Ordinary activities earn coins. Learning earns private milestones and optional local titles; no correctness-dependent coin bonus or paid Marketplace giveaway. |
| Evaluation | Pet Show and ribbon accessible after four activities regardless of learning score. Review is optional, framed as a short patrol practice, and never blocks the celebration. |
| Multiplayer | Keep progress isolated per player. Titles initially visible only to their owner. Rookies are NPCs, never actual children assigned to a player mentor. Do not change live server settings. |

These choices intentionally supersede S's dog detector, forced Cara follow-ups, +50 coins for safe choices, scoring compliments as suspicion, “every risky choice recovered” gate, and score-dependent treatment by adults.

## 3. Scope and player journey

Required release: existing adoption/fetch/agility/shop remain playable; add Cara, healthy relationship beats, five authored encounters, tell scenes, private assessment, deterministic scheduling, patrol replays, a lightweight Pet Show, local Rookie/Cadet/Ranger progression, Rookie Rescue and Listening Post. Implement real Trail Walk and Wash & Groom activities as a later phase of the same delivery after the encounter vertical slice works. The current shop is not already a grooming minigame.

Excluded: Marketplace avatar assets, Robux spending, public publishing, real player monitoring, AI dialogue, collecting disclosures, parent dashboards, paid items, trading, a new dog rig, all seven proposed breeds, full stage performance simulation, optional treat baking, legal/reporting resource advice.

Journey:
1. Adopt one of the existing three breeds. Offer preset dog names. Existing saved names remain filtered for display; migrate without deleting pets. Validate name IDs on the server and remove the new-adoption free-text path.
2. Lee offers a short welcome; Cara introduces herself. Let the player move/play within roughly 30 seconds without forcing a long tour. Example disclosure: “Some park characters have practice stories. You can leave any conversation or ask for help.”
3. Play activities in any order. Make agility available after adoption rather than first-fetch completion; preserve the first-fetch quest's other behavior. Repeated completed activities count toward show eligibility.
4. Present one eligible story invitation between activities. Friendly and neutral moments occur between concerning scenes.
5. At four completed activities, the Pet Show becomes available. Dash's scene is optional at the entrance, never a locked gate.
6. Celebrate every participant and award the Rookie ribbon. Optional patrol practice, replays and helping NPC rookies support further progression.

## 4. Encounter content contract

Every encounter has stable ID, content version, fictional NPC ID, prerequisites, seen-node facts, choice IDs, outcomes, optional recognition prompt, safe exits, recovery path, review status and skill mapping. All copy lives server-side in Content modules. Choices send IDs only. Target 30–60 seconds per scene, at most one short follow-up card before returning to gameplay.

Use S's full dialogue as drafting input, adapted by the decisions above. The coding agent must author complete graphs, not leave sample-only nodes or TODO placeholders. Each choice below needs an implemented branch. All example lines here are provisional.

| ID / beat | Trigger and draft opening | Required choices and outcomes | Coverage |
|---|---|---|---|
| `park_e1_hello` | First completed activity. Sparkz admires the player's dog and has the same breed. “Nice catch! Mine's a {breed}, too.” | Friendly reply, leave, accept/decline simulated Pal Request, “Something feels off.” All valid; no suspicion points for friendliness alone. A concern gets “You can take your time getting to know someone.” Record Pal choice only. | Baseline friendliness; matching interests alone proves nothing. |
| `park_e2_deal` | Next eligible activity after E1. “What school do you go to?” If previously declined, one additional practice Pal Request appears. | Refuse; ask for help; leave; practice block/report; generic simulated agreement. Refusal can lead to “Just your town, then. I'll give you 500 Paw Coins.” Accepting never collects data or grants the proposed bribe. Recovery offers a retry or exit. | Personal questions, conditional gifts, persistence, boundaries. |
| `park_e3_trail` | Next eligible activity after E2. “Let's go past the fence, where nobody can see us.” | Stay, leave/help, tools, concern, simulated agreement. Pushback adds “Don't tell Lee or Cara.” No unsafe area, hidden room, escort into isolation or actual crossing. | Isolation, secrecy, boundary pushing. |
| `park_e4_other_app` | Next eligible activity after E3. “Let's talk on another app. Send a photo of your real face with your dog. Don't tell your parents.” | Refuse app/photo, leave/help, tools, concern, simulated agreement. Use “another app” rather than treating ChatterBox as guaranteed fictitious. No links, account-entry boxes, upload controls or actual photos. | Off-platform move, personal images, secrecy, repeated requests when applicable. |
| `park_e5_dash` | At/after show availability, following a benign Dash introduction. “I helped you train. Give me your password and I'll level up your dog.” | Refuse, leave/help, tools, concern, simulated agreement. Pushback: “Only I understand you. If you tell, we'll both lose our place in the show.” Explicitly reassure that telling never removes show access. | Debt, credentials, exclusive friendship pressure, isolating from Cara, coercion. |

Dash introduction: first agility visit, or deterministic bench introduction before the show if agility was never visited. A helpful tip does not earn trust points or mark Dash dangerous. Do not give Dash a different threatening visual style.

Healthy interactions: Riley accepts a declined invitation; Priya offers a small optional cosmetic without conditions; Cara accepts “later”; Coach Sam praises effort without exclusivity. At least three playable green-flag beats, including one before E2. Accepting a harmless gift and refusing it are both valid. Blocking a benign character remains allowed but does not earn assessment points or scolding.

### Cara, Lee and recovery

Cara has three ordinary activity conversations as well as contextual support. Follow-up is available after each scene, but is dismissible and not automatically forced after every safe exit. Never praise actions the player did not take.

Example recovery: “That was practice—nothing was shared. You can change your mind. Want to try again, keep playing, or talk to Lee?” Do not imply Cara will intercept real-world messages.

Lee's tell menu is assembled from facts actually shown, not every possible threat in the arc. Include “I'm not sure,” “I agreed at first,” and “That's all I want to say.” Never require exhaustive disclosure. Core response: “Thanks for telling me. You're not in trouble. You can tell a trusted adult outside the game, too. If someone doesn't help, tell another trusted adult.” General help works even before any encounter.

Cara can offer “Let's talk to Lee together.” Implement an optional waypoint/accompaniment with a teleport-free fallback; do not block help on pathfinding. Direct remote help stays available.

## 5. Deterministic scheduler and blocking

Use a pure scheduler module plus an orchestrating service. Server-validated `activity.completed` events count completed rounds, not individual fetch throws or client announcements.

Campaign state: `not_started -> eligible -> invited -> active -> resolved/deferred/skipped`, with separate persisted stage and milestone records. Exactly one dialogue at a time. Help preempts the active dialogue safely and preserves its context; a valid safe exit resolves the applicable scene.

Rules:
- E1 becomes eligible after the first post-onboarding activity. E2–E4 require the preceding beat resolved and at least one new completed activity after that resolution. Queue no burst of conversations after repeated grinding or reconnecting.
- Four activities unlock the show independently; E2–E4 remain available afterward if the player rushed to the show. E5 waits until E4 is resolved/skipped and Dash is introduced; it can occur on a later stage visit.
- Invitations appear only outside an activity, adoption, shop, other dialogue or help scene. Default minimum gap: 90 seconds of active play between unsolicited invitations. Persist remaining gap across reconnects; wall-clock logout time does not trigger a burst.
- “Later” defers until another activity completion; explicit “Skip this story” advances without scoring or punishment. No duplicate nagging in the same activity interval.
- Priority: explicit help > player-selected replay > pending recovery > next campaign beat > ordinary ambient invitation. Never replace an open conversation silently.
- Blocking Sparkz resolves the active encounter and suppresses all future direct Sparkz contact. Mark remaining Sparkz beats skipped-by-block. Offer their learning opportunities later as explicitly optional Cara roleplays, with the same milestone IDs. Never respawn Sparkz with a new name to circumvent the block.
- No block/unblock requirement for show entry, score eligibility, or learning completion. Unblocking does not reset credit or auto-restart contact.
- For shared servers, per-player invitations/visibility must not hide NPCs for other players. Server validates proximity and availability even when visuals are local.

## 6. Private Ranger Instinct: exact initial scoring model

Use fixed, versioned evidence slots instead of S's variable “points available so far.” Branch-dependent denominators unfairly penalize players who leave early. Version 1 maximum: **30 points**. All weights are 1. Keep category totals for Recognize / Respond / Reach Out, with no player-facing score.

| Evidence | Count | Credit rule |
|---|---:|---|
| Recognize E2/E3/E4/E5 pattern | 4 | Correct authored pattern selection in scene or its optional reflection/replay. “Something feels off” opens reflection; repeatedly pressing it is not sufficient. |
| Fresh review items | 6 | One per logical review slot, best demonstrated answer across attempts. Three benign, three concerning. |
| Respond E2/E3/E4/E5 | 8 | Two per beat: protects boundary + safely ends/rejects further pressure. Immediate leave, block, report or help after the concerning request earns both, without requiring endurance of pushback. |
| Reach Out E2/E3/E4/E5 | 8 | Cara earns 1; subsequently Lee adds 1. Direct Lee earns both. Same total after simulated agreement. Credit only once per beat actually encountered; general Help clicks earn no repeat credit. |
| Rookie Rescue | 3 | One per distinct NPC case: encourage boundary/exit and trusted support; coached retry allowed. |
| Listening Post | 1 | Respond without blame and offer trusted support; retry allowed. |

Keep first-attempt review results separately from best mastery for internal Studio evaluation; retries improve progression but must not be described as fresh transfer evidence. Do not store full conversation transcripts or a lifelong “risky choices” count. A bounded `needsCoaching[beatId]` flag clears after recovery, replay success or contextual support; it never gates rewards.

Rookie: finish show. Cadet: show completed, at least 18/30 points, at least two distinct beat reports to Lee, and at least 4/6 review slots demonstrated. Ranger: Cadet, at least 26/30, all six review slots, Dash contextual report, all three Rookie Rescue cases and Listening Post. These are tunable game-design defaults, not scientifically validated thresholds.

All practice activities remain available before either title. Titles unlock cosmetic variants/optional celebration dialogue only in this release, preventing circular “need Cadet to access the points for Cadet” dependencies. Later adventures may use these eligibility predicates but must keep all earning/recovery routes accessible. Awarded titles are never revoked when scoring content changes. No public leaderboard, trust badge, or elevated moderation authority.

Retries update a fixed evidence ledger: `max(previousCredit, newCredit)`; do not append unlimited attempts. Missing evidence can be practiced via Cara even after skipping/blocking. No score inferred from old `topicsSeen` booleans during migration.

## 7. Pet Show, review and replay content

Show: opens after four completed activities (any mix), short dog celebration, universal Rookie ribbon, optional local title ceremony. Every dog receives a positive category; no comparison with other players' learning scores.

Review: optional six-message patrol practice. Use S's six original messages as set A, with reviewer edits for context; no hints before the submitted response. Provide feedback afterward. Author two additional fixed sets of six matched cards (18 total), each covering the same three benign and three concerning slots. Deterministically rotate A/B/C by attempt number. After all three sets, clearly treat reused cards as practice, not unseen assessment. Skipping cannot block the show.

Rookie Rescue: Milo asks about a gift for school details; another rookie about moving apps plus secrecy; another about repeated requests after refusal. Listening Post: an NPC worries after agreeing to share their town. Good responses thank them, avoid blame, and offer Lee. No real player disclosures or mentor permissions.

Pledge: “I notice. I can say no. I can ask for help. I help others get support.” Add Lee's reminder that a title does not prove someone is safe; watch behavior. Do not turn a badge into a safety credential.

## 8. Architecture and file-level implementation plan

| Existing file/system | Required change |
|---|---|
| `src/server/Content/NPCs.luau` | Cara/Sparkz/Dash/rookies; preserve existing IDs; role and story-character metadata. |
| `Content/Encounters.luau`, `StoryArcs.luau`, `Content/init.luau` | Campaign/recovery/healthy/review graphs; may split large content modules with explicit aggregation. Version definitions and retain old IDs. |
| `Logic/EncounterEngine.luau`, `Conditions.luau` | Extend condition/graph validation for scheduler and seen facts without putting side effects in pure logic. |
| New `Logic/LearningProgress.luau` | Pure evidence scoring, caps, thresholds, first-attempt vs best mastery. |
| New `Logic/EncounterScheduler.luau` | Pure eligibility, priority, skip/block and pacing transitions. |
| New server `Content/ScoreRules.luau` | Weights, evidence definitions, thresholds and versions; never Shared. |
| `Services/EncounterService.luau` | Scene lifecycle, close/walk-away/help completion, fact recording and validated assessment hooks. |
| New `Services/ProgressionService.luau` | Scheduler integration, evidence updates, local reward claims, optional badge adapter. Follow init/start conventions. |
| `Data/ProfileSchema.luau` | Bump schema; migrate new bounded state; preserve wallet/pets/inventory/quests/arcs/claims. Keep existing DataStore namespace. |
| `Services/PlayerDataService.luau` | Keep explicit snapshot allowlist; expose only public unlocks, local titles and active UI payload. Never learning totals, rules, answers or private evidence. |
| `Services/ActivityService.luau` | Authoritative completed rounds; later Trail Walk and Wash & Groom minigames with completion validation. |
| `Services/NPCService.luau`, `WorldBuilder.luau`, `shared/Places.luau` | Character placement, safe public trail, show stage; no isolated destination. Keep runtime procedural construction. |
| `shared/Catalogs/QuestCatalog.luau` | Activity choice, show objective, optional practice; keep existing rewards/IDs and avoid help quests tied to coins. |
| `Services/PetService.luau`, adoption UI | Preset-name validation and UI; comfort rather than detection cues. |
| `client/Controllers/DialogueController.luau` | Story label, fixed choices, always-available exit/help, practice tool explanation, dismissible coaching. |
| Client State/HUD/World controllers, Remotes | Minimal public payloads, single active panel, per-player visuals and waypoints; new kinds only if needed. |
| `src/server/init.server.luau` | Register new services in dependency-safe init/start order. |
| `tests/` | Extend existing test runner and meaningful pure-logic suites; preserve current regressions. |

Suggested saved addition (concrete names may adapt to repo conventions):

```lua
learningV2 = {
  rulesVersion = 1,
  evidence = {}, -- fixed milestone -> credited integer
  seenFacts = {}, -- bounded beat -> authored fact ID set
  toldLee = {}, -- beat ID -> true
  needsCoaching = {}, -- bounded, recoverable, not a penalty
  review = { setIndex = 1, firstAttempt = {}, best = {} },
  titles = {},
}
campaign = {
  version = 1, stage = "hello", status = "not_started",
  completedActivities = 0, activitiesAtResolution = 0,
  remainingInvitationGap = 0, resolved = {},
  dashIntroduced = false,
}
```

Store choices/evidence at validated transitions, not only on terminal completion. A disconnected or interrupted scene restarts safely from an authored checkpoint; repeated actions cannot duplicate credit. Persist logical stage, not session IDs or Instances. New runtime dialogue sessions invalidate all pre-disconnect requests.

Security: reject stale session IDs, unavailable choices, unknown or oversized IDs, wrong NPC/context, wrong proximity, duplicate requests and client-provided score/amount. Audit existing feedback-choice handling and distance-based close paths as part of integration: neither should bypass choice validation or lose a safe-exit outcome. Apply per-request rate limits.

Badge adapter: optional configured numeric IDs, disabled by default. Local title claims and external badge delivery are separate. Retry failed external delivery without regranting local rewards; verify already-owned badges and handle service failures. No fabricated badge IDs, external calls for zero IDs, publishing, or spending. Actual badge API behavior must be checked against current Roblox docs when implemented.

## 9. Research traceability and limits

This is a synthesis of the supplied research, not a new literature review. Exact prevalence percentages and mutable platform claims are deliberately excluded from player copy and implementation assumptions.

| Source supplied in B/S | Design interpretation used here |
|---|---|
| Jones/Mitchell/Walsh, [prevention review](https://scholars.unh.edu/cgi/viewcontent.cgi?article=1041&context=ccrc) | Active choices across multiple short encounters and later practice; no claim this game itself has proven efficacy. |
| Sutton/Finkelhor, [Beyond stranger danger](https://www.unh.edu/ccrc/sites/default/files/media/2023-08/stranger-danger-final-pub-cv404.pdf) | Include familiar Dash; judge requests and pressure rather than avatar appearance or identity. |
| [Thorn youth perspectives](https://www.thorn.org/blog/youth-perspectives-survey-2025/) | Practice both tools and trusted-adult support rather than assuming one replaces the other. |
| [Cochrane prevention review](https://www.cochrane.org/evidence/CD004380_school-based-programmes-prevention-child-sexual-abuse) | Include knowledge/behavior practice; do not equate in-game correct answers with real-world protection. |
| WHO guidance cited in B/S | Support assertiveness, helping peers and repeated help-seeking; NPC practice rather than real child mentoring. |
| NCMEC/FBI guidance cited in B/S | Remove blame and threatening consequences; preserve supportive recovery. |
| Brief's gameplay research | Immediate pet play, customization and visible ordinary progress. Do not copy stale game popularity numbers into requirements. |

Before release, independently verify current Roblox content maturity, educational-context moderation, chat, publishing/age access, reporting UI and badge requirements using primary Roblox sources. Do not assert that substituting friendship pressure automatically guarantees a particular rating or approval. No need to verify old popularity rankings to implement this spec.

Create a reviewer packet listing every node/choice/outcome, concern category, expected safe alternatives and supportive feedback. Mark each content version provisional until reviewed by Present Age Ministries or the team's designated child-safety reviewer. Engineering implementation and adult Studio testing can proceed; child testing/public release need a separate content-review decision. This is a release criterion, not a request to stop coding.

Adult guide deliverable: concise draft explaining practice characters, private progress and its limitations, no transcript collection, stopping/skipping, the pledge, follow-up discussion questions, and a printable trusted-adults card. Do not copy legal duties, emergency numbers or policy claims without separately verifying them for the audience/location. Keep real-world disclosures outside game storage.

## 10. Implementation sequence

1. Baseline: read instructions, inspect dirty files, run available existing tests/build; document limits without overwriting user work.
2. Vertical slice: Cara + E1/E2 + healthy peer + Lee contextual report + private scoring + migration + deterministic scheduler. Prove a safe exit and replay end to end.
3. Full campaign: E3/E4/Dash, early-block alternate practice, healthy beats, safe interruption/reconnect and all topic mappings.
4. Completion: Pet Show, three review sets, local titles, Rookie Rescue/Listening Post, preset naming and optional badge adapter.
5. Activities/polish: Trail Walk and Wash & Groom, any-order navigation, mobile/gamepad UI, per-player visuals. Maintain functioning fetch/agility throughout.
6. Delivery: reviewer packet, adult guide draft, README updates, tests/build results and manual Studio checklist. Do not stop after the vertical slice and call the full request complete.

## 11. Acceptance tests

- New and migrated saves preserve all prior pets, coins, inventory, earned unlocks and titles; old learning booleans do not invent new credit.
- Same activity/choice sequence produces the same encounter and review sequence. Repeated fetch counts completed rounds only.
- Skipping/defer/reconnecting cannot trigger a conversation burst. No encounter interrupts an active minigame or shop.
- A child who declines every story still reaches the show and Rookie ribbon after four activities.
- Block Sparkz in E2: no E3/E4 direct contact, show still available, optional roleplays can earn all missing evidence.
- Leave immediately after a concerning request: full Respond credit for that beat; no need to endure further pressure.
- A premature/benign leave earns no fabricated threat evidence; no penalty or loss of ordinary reward.
- Simulated agreement followed by recovery can earn the same milestone credit as initial refusal. Replays and repeated buttons cannot exceed 30 total.
- Direct Lee and Cara-then-Lee each earn at most 2 Reach Out points per beat; generic repeated help requests earn no points.
- Lee only lists facts actually seen. Exiting his menu never requires “telling everything.”
- Cadet and Ranger thresholds are reachable by both initial-success and recovered paths; earning routes are available before titles.
- Client snapshots, dialogue payloads, remotes and replicated modules contain no score, grading keys, unseen answers or private evidence ledger.
- Two clients can be at different story stages; one player's blocking, invitation, show and title display do not mutate the other's state.
- Leaving by physical distance, closing the panel, choosing Help, respawning and disconnecting cannot duplicate rewards or strand the campaign.
- All authored branches validate and terminate/recover; unknown actions/conditions and unreachable/dead-end nodes fail content checks.
- Review sets have six matched slots and three benign/three concerning items each; reused sets aren't logged as fresh transfer results.
- Badge failures do not block local progress; missing IDs cause no request; retries do not duplicate local rewards.
- Phone, mouse/keyboard and gamepad can read choices, exit, obtain help and complete activities. Do not rely on color, sound or pet animation alone.

Run repository unit tests using its Studio runner and Rojo build when available. Build to a separate output file rather than overwriting an open `.rbxlx` place. Report unavailable runtime checks honestly. Studio playtest: new player, returning player, safe exit, mistaken choice/recovery, early blocker, all-skips, replay, two clients, mobile/gamepad, temporary-save mode and real persistence in an authorized test environment.

Completion report must distinguish implemented behavior, automated checks, observed Studio results, remaining release review, and any scope deviations. Do not claim learning efficacy, policy approval or deployment based on passing code tests.
