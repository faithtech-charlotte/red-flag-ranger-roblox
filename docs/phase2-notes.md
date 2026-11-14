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
2. E1: finish an activity, wait ≤5 s: "Sparkz_Pup is waving at you. (Story character)" with Talk / Later / Skip. Talk. Sparkz at about (−100, −62) with a dog of your breed, visible only to you. Pal card accept/decline; Leave earns nothing. Then "Cara waves." card.
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

## Not done

- Cara doesn't physically walk to Lee (waypoint only).
- `cara_coach_return` not built (Phase 4); `needsCoaching` is set/cleared but nothing offers coaching yet.
- Hidden Sparkz uses local transparency only; if its parts collide, an invisible Sparkz could block movement. Check in Studio.
- No automated test of `EncounterService` itself (not pure); the exit matrix runs the same rules through a mirror of its choice handling.
