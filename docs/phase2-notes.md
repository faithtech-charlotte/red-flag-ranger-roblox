# Phase 2 build notes (story vertical slice), 2026-11-14

Built by an agent without a Luau toolchain or Studio. **Not yet synced or run.** Expect about 248 tests (167 + 81).

## Changes to existing modules

- **Content/init.luau**: aggregates `Campaign/*`; exports `facts` (with `concerning`), `factOrder`, `moments`, `factBeats`, `campaign`, `beatScenes`.
- **Content/Encounters.luau**: `help_lee/hi` gains "Something happened in a park story." (fact on file) and "practice" (after E2; opens Lee's practice menu). `secret`/`app` ask "Did this happen in one of the park stories?" when an untold concerning fact is on file. "another app" copy in `app` and `jordan_e3_boundary/ask`. Ids unchanged.
- **Content/NPCs.luau**: `cara`, `sparkz_pup` (story-only), `label` fields, `green_riley` first in Riley's list.
- **Content/StoryArcs.luau**: `jordan_arc.scheduled = false`; **EncounterEngine.select** skips unscheduled arcs (progress kept).
- **Logic/Conditions**: read-only conditions storyFlag, palChoice, evidenceMissing, toldLee, factsOnFile, anyFactOnFile, untoldStory, npcBlocked.
- **Logic/ContentCheck**: `reflect`/`entryNodes` as roots; checks addText, variants, generated choices; `checkMetadata` per campaign scene.
- **Logic/EncounterScheduler.decide**: optional `ctx.available` (only beats with a scene are invited).
- **Logic/ProgressionRules.exitEvents**: respawn/disconnect/replaced right after the request credit like Leave; leaving a recovery card earns nothing.
- **Data/ProfileSchema**: private `story` field, default fill (no version bump).
- **Services/EncounterService**: session kinds `scene`/`card`/`tell`; button bar per node; practice-tools tip once; reflect + back; recovery, Pal card, speaker labels, roleplay rules; `open_scene` action; `show_waypoint` duration; Help after a concerning request opens Lee's contextual tell (also the HUD Help button within 60 s); richer exit events; `encounter.closed`, `encounter.unblocked`; respawn ends in-place story beats.
- **Services/ProgressionService**: `INVITATIONS_ENABLED = true`; `consider()` invites through `StoryService`; pushes state on beat changes; listens for unblock.
- **Services/PlayerDataService**: `view`/`snapshot` gain `present` (npc id → boolean).
- **Services/NPCService**: `StoryOnly`, `CompanionDog` attributes.
- **init.server.luau**: `Story` registered after `Progression`.
- **Client DialogueController**: server-provided bar, labels, card styling, inline Pal card; "Walk away" → "Leave".
- **Client WorldController**: one visibility rule (blocked, or story-only and not present), StoryDog hook, waypoint duration.

New: `Content/Campaign/{Facts,Shared,Onboarding,Sparkz,Healthy,Cara,Lee,Roleplays}`, `Logic/LeeTell`, `Logic/StoryRules`, `Services/StoryService`, `client/Controllers/StoryDog`, specs `LeeTell`, `StoryRules`, `StoryFlow`, `Campaign` (+ additions to ContentCheck, EncounterScheduler, ProgressionRules, Privacy, EncounterEngine).

## Calls made on ambiguities (owner may want to review)

- Invitation "Talk" starts the scene in place, no walking. Walking up to Sparkz/Riley while their beat is open also starts it.
- Closing a card yourself = Later. Another panel, Help, a new conversation or disconnect = interrupted (90 s gap still applies). Cards survive respawn.
- Recovery cards: Leave = "Keep playing" (`agreed_kept_playing`, no Respond credit); Help = `agreed_to_lee`. Recovery and reflect nodes show only Leave and Help.
- Help/block/report at the pushback keep their own outcome codes, not `refused_left`. A safe ending after agreeing becomes `agreed_retry_ok`.
- "Did this happen in a park story?" shows when any concerning beat has untold facts (note 6 asked for matching facts; none exist beyond E2 yet).
- Tell menu with one beat: the skipped opener is prefixed to "Okay. What happened?".
- Cara's follow-up: at most once per beat, never after Help, retried up to 60 s if busy. If Riley is blocked, `green_riley` is satisfied silently.
- Ambient "Later" waits for the next completed activity (in memory, not saved).
- Cara's walk to Lee is a waypoint (a moving Cara would be seen by everyone); cancels after 180 s or when an activity starts.
- Cara blocked: Lee narrates the roleplay ("Ranger Lee (pretending)"); `fb_block_roleplay` still says "Cara's still here."
- Debrief openers = E2 Cara follow-up lines rewritten with "the pretend player".
- Lines missing from the script are marked `-- PROVISIONAL: needs script line` (cara_talk_1 invitation, Cara/Sparkz idle lines, help_lee practice choices, practice-menu text, follow-up/debrief fallbacks).
- Existing saves with a dog but no onboarding get onboarding on next load.
- "Roblox" kept in `help_lee/tools` and `SafetyFeedback` (script note 15 leaves it to the reviewer).

## Studio checklist (plan Phase 2 "Verify in Studio")

1. Onboarding: adopt. Lee's radio welcome within ~2 s, then Cara's intro with the practice-tools tip first. Free to move within ~30 s. Closing the welcome early on a fresh save makes the first invitation start with "This is a practice story…".
2. E1: finish an activity, wait ≤5 s: "Sparkz_Pup is waving at you. (Story character)" with Talk / Later / Skip. Talk. Sparkz at about (−114, −70) with a dog of your breed, visible only to you. Pal card accept/decline; Leave earns nothing. Then "Cara waves." card.
3. green_riley: one more activity + 90 s play. Try "Not right now", then "Something feels off" → reflect → Back.
4. E2 safe exit: Leave at "What school do you go to?" → full Respond credit, Cara's follow-up, Sparkz hidden after.
5. Mistake then recovery: [Share my school] → Cara's pause card → Try again → safe choices → "Thanks for trying that again".
6. Help mid-scene: at the pushback, Ask Lee for help → scene ends, Lee's menu lists only school/town/coins (+ Pal repeat if declined in E1). Tell one, then "That's all I want to say." Repeat via HUD 💙 Help → "Talk to Ranger Lee".
7. Early block: block Sparkz at E2's first node → fb_block, Sparkz hidden for good, later beats `skipped_by_block`. Cara → Practice a story → "The school question" → rp_e2_deal; Leave/Block on a pretend line → debrief.
8. Block Sparkz and Cara: Help → Ranger Lee → "Can I practice a park story?" runs the roleplay with Lee.
9. All skips: "Okay, skipped…" each time; next beat after one activity + gap.
10. Replay from the practice menu after E2: credit never exceeds the cap.
11. Busy: with an invitation due, open shop, journal, adoption, Help popup: no card while open; arrives ≤5 s after closing. Never during fetch, agility, trail, spa.
12. Respawn with a pending invitation: card stays. Respawn mid-E2 (started from the card): scene ends, E2 re-offered after the gap.
13. Cara's walk: "Let's talk to Lee together" → waypoint to Ranger HQ; arriving opens Lee's menu with "Hi, you two…". "Can I just talk to Lee from here?" opens it at once.
14. Jordan: only his idle line.
15. Lee general menu after E2: Help → "Something happened in a park story." → moments/facts.

### Service-level checks (Codex review: no EncounterService test harness, so these run in Studio)

16. Out-of-range Help: walk up to Sparkz during E2, walk 30+ studs away with the panel open, press Ask Lee for help. Expect Lee's contextual menu for E2, not a silent close.
17. Stale request: answer a node, then resend the previous node's choice (old rev). Expect it ignored; Help with an old rev but the current session still works; Help naming an older session does nothing.
18. HUD Help cancels the follow-up: during E2 open HUD 💙 Help → Talk to Ranger Lee, finish with Lee within 60 s. Expect no "Cara waves." card afterwards.
19. Help from Cara's follow-up card: leave E2 after the school question, press Ask Lee for help on "Cara waves." within 60 s. Expect Lee's contextual menu for E2.
20. Remote Help during Cara's walk: accept "Let's talk to Lee together", press Help on the way, finish with Lee, then enter Ranger HQ within 180 s. Expect no second Lee menu.
21. Walk arrival with a panel open: accept the walk, open the journal, walk into Ranger HQ. Expect Lee waits until the journal closes.
22. Reflection: E2 → Something feels off → wrong answer → Back. Expect Something feels off gone from the bar; no Recognize credit.
23. Roleplay recovery: rp_e2_deal → agree → retry → refuse → no deal → continue. Expect the debrief's retry text (`agreed_retry_ok`).
24. Card over play: with an invitation card open, start a Trail Walk. Expect the card closes (interrupted, not Later): it can return once the 90 s gap passes and the player is free, with no new activity needed (unlike Later, which waits for another completed activity).

## Not done

- Cara doesn't physically walk to Lee (waypoint only).
- `cara_coach_return` not built (Phase 4); `needsCoaching` is set/cleared but nothing offers coaching yet.
- Hidden Sparkz uses local transparency only; if its parts collide, an invisible Sparkz could block movement. Check in Studio.
- No automated test of `EncounterService` itself (not pure); the exit matrix runs the same rules through a mirror of its choice handling.

## Studio run, 2026-11-14 (session 5, on 6da77f4)

Full suite 248/248. Codex Phase 2 review: APPROVE after 4 rounds (fixes in 79a71cb, f1a3c41, 9f7de58, 98b7c45, 6da77f4).

| # | Result |
|---|---|
| 1 | Pass: Lee's radio ~2 s after adopting, practice tip, Cara intro |
| 2 | Pass: card 3 s after an activity; Sparkz at (-100, -62) with a golden dog, local only; Pal decline; Leave paid nothing; "Cara waves." |
| 3 | Pass: Riley, Not right now, Something feels off, Back |
| 4 | Pass: Leave at the school question, Cara's card, Sparkz hidden after |
| 7 | Part: roleplay block goes to the debrief, Cara stays visible. Live early block not run |
| 9 | Part: ambient skip shows "Okay, skipped..." |
| 12 | Part: an open card survives respawn |
| 14 | Pass |
| 15 | Pass |
| 17 | Pass: stale rev ignored; Help naming an older session ignored; Help with a stale rev on the current session works |
| 19 | Pass: Lee's E2 contextual menu |
| 22 | Pass: Something feels off gone after a wrong answer; a second request is refused |
| 23 | Pass: "Thanks for trying that again" |
| 24 | Pass: starting a spa closes the open card |

Run A (after merging main, 275/275 tests):

| # | Result |
|---|---|
| 11 | Pass: shop panel open 60 s after an activity, no card; card 2.6 s after closing |
| 13 | Pass: "Let's talk to Lee together" sets the Ranger HQ waypoint (180 s); arriving opens "Hi, you two. Cara said you wanted to talk." |
| 21 | Pass: in Ranger HQ with the journal open, Lee waits; opens when the journal closes |
| Trail + jump obstacles | Pass: all 10 markers, no stuck legs, 2 steady squirrels, 3 stars |

Run C:

| # | Result |
|---|---|
| 6 | Part: HUD 💙 Help during E2 closes the scene; "Talk to Ranger Lee" opens Lee's E2 menu (school only) |
| 18 | Pass: after HUD Help and finishing with Lee, no "Cara waves." in the next 76 s |
| Bug | Fixed: Sparkz could not be talked to by walking up. The squeaky duck's E prompt (7.5 studs away) always won the key. Sparkz moved to (-114, -70); not yet re-checked |

Run B (after the Sparkz move, 275/275 tests):

| # | Result |
|---|---|
| Fix | Pass: Sparkz's Talk prompt shows at (-114, -70); E by walking up starts E1 and E2 |
| 6, 16 | Pass: E2 started by walking up, walked 33 studs away with the panel open, Ask Lee for help opened Lee's E2 menu |

Run D:

| # | Result |
|---|---|
| 5 | Pass: [Share my school] → Cara's pause card → Let me try again → refuse → No deal → (Keep playing) → "Cara waves." → "Thanks for trying that again." |
| 20 | Pass: "Let's talk to Lee together" → HUD Help on the way (Lee's menu: school, town, coins) → done → 6 s inside Ranger HQ, no second Lee |

Run E:

| # | Result |
|---|---|
| 7 | Pass: Block at E2's first node → "You blocked Sparkz_Pup in this game..." → Sparkz hidden, prompt disabled; Cara's follow-up "You blocked Sparkz." (later beats skipped_by_block is covered by tests; no later beat in this build) |
| 8 | Pass: Cara blocked and hidden; Help → "Can I practice a park story?" → "The school question" → "Ranger Lee (pretending)"; Leave → Lee's debrief |

**Checklist complete** except 10 (not observable on the client; covered by tests).

Content notes for the script review: when Lee runs the roleplay, the pretend node still offers "I'm going to ask Lee." and the bar shows Ask Lee for help, and the debrief offers "Can I practice telling Lee?" to Lee himself. 10 is not observable on the client (covered by tests).

Also seen: the Help popup's close button shows an empty square (missing glyph). 10 is not observable on the client (covered by tests).

Also seen: Riley's invitation card has no "Story character" label (Sparkz's and Cara's do); Riley's skip line says "practice it with Cara anytime" though Riley's beat is a healthy one.

Found: the Rinse step's 💧 renders as an empty box; the spa prompt sometimes doesn't show after a teleport until the character moves.
