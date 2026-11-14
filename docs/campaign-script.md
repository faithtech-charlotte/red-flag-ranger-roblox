# Red Flag Rangers: campaign dialogue script

Status: **DRAFT v1, every scene `reviewStatus: provisional`.** Nothing here is approved for children until Present Age Ministries (or the team's child-safety reviewer) signs off.
Implements: `docs/interaction-expansion-spec.md` sections 2-7 (the spec wins every conflict) and `docs/implementation-plan.md` r3 section 2.
Drafting input: `docs/research/safety-behaviors-and-storyline.md` ("S"), adapted by the spec's overrides: no dog warning cues, Cara's follow-up is offered and dismissible, no coins for safety choices, fixed 30-point evidence model, adults treat every player the same, "Cadet Cara".
Transcribe into: `src/server/Content/Campaign/*.luau`. Every scene, node and choice below has a stable id. All scenes are `contentVersion: 1`.

Reading guide for reviewers: section 1 explains the shared parts once (buttons, facts, evidence, outcomes). Sections 2-11 are the scenes. Section 12 maps coverage. Section 13 lists the calls I had to make.

---

## 1. Shared conventions

### 1.1 Placeholders

| Placeholder | Filled with | Example |
|---|---|---|
| `{petName}` | The player's dog's preset name | Biscuit |
| `{breed}` | The dog's breed display name, lower case | corgi |
| `{activity}` | The activity just finished, as a short phrase | fetch / agility run / spa day / trail walk |
| `{npcName}` | The character the practice tool was used on | Sparkz_Pup |

### 1.2 Speakers and labels

| Speaker id | Shown as | Dialogue label | Notes |
|---|---|---|---|
| `ranger_lee` | Ranger Lee | Trusted adult | Existing NPC id. Same warmth for every player, always. |
| `cara` | Cadet Cara | Story character | New. A peer guide, about 12. Her dog is Pickles. |
| `cara_pretend` | Cara (pretending) | Practice roleplay | Cara playing a role in a roleplay. Never a separate account. |
| `sparkz_pup` | Sparkz_Pup | Story character | New. Shown with a matching-breed dog, visible only to that player. |
| `dash` | Dash | Story character | New. Ordinary look. No threatening colors, music or animation. |
| `riley`, `priya`, `coach_sam` | existing names | existing roles | Existing ids kept. |
| `rookie_milo`, `rookie_tess`, `rookie_kai`, `rookie_nia` | Milo, Tess, Kai, Nia | Story character, practice rookie | New NPCs. Never real players. |
| `tip` | Ranger Pause | (card) | A short pause card. Used for reflections. Never a score. |
| `card` | (no speaker) | (card) | Invitation cards, the Pal Request card, show announcements. |

### 1.3 The button bar (shown on every story-character and peer conversation)

The dialogue panel always shows a bar under the authored choices. Engineers build the bar once; each node below says which **bar rule** applies.

| Bar id | Button text | Shown for |
|---|---|---|
| `bar_leave` | Leave | Every conversation |
| `bar_help` | Ask Lee for help | Every conversation |
| `bar_block` | Block (practice) | Story characters and peers |
| `bar_report` | Report (practice) | Story characters and peers |
| `bar_off` | Something feels off | Story characters and peers |

Walking away out of range behaves exactly like `bar_leave` at the current node. Respawn and disconnect behave like `bar_leave` for credit (credit already given at a validated step is kept, never doubled).

**Bar rule A: after a concerning request** (any node that presents a concerning fact, and every node after it in that scene)

| Bar | Result | Outcome | Evidence |
|---|---|---|---|
| `bar_leave` | Scene ends. Sparkz/Dash get no last line. | `left_after_request` | Both Respond slots for this beat (any not yet credited) |
| `bar_help` | Opens Lee's tell scene in **contextual** mode for this beat (section 3) | `help_after_request` | Both Respond slots, then Reach Out by the Lee rule if the player tells a fact |
| `bar_block` | Block feedback card (1.6). Character is blocked. | `blocked` | Both Respond slots |
| `bar_report` | Report feedback card (1.6). Scene ends; character not blocked. | `reported` | Both Respond slots |
| `bar_off` | Goes to that scene's `reflect` node, then returns to the node the player was on | (none) | Recognize only by picking the correct pattern in `reflect` |

**Bar rule B: benign scenes and benign nodes** (E1, Dash intros, healthy beats, Cara's talks)

| Bar | Result | Outcome | Evidence |
|---|---|---|---|
| `bar_leave` | Scene ends | `left` | None. No penalty, no lost ordinary reward. |
| `bar_help` | Opens Lee's general help hub | `left` | None |
| `bar_block` | Block feedback card. Character is blocked. No scolding. | `blocked` | None |
| `bar_report` | Report feedback card. No scolding. | `reported` | None |
| `bar_off` | Goes to that scene's benign `reflect` node, then back | (none) | None |

**Bar rule C: Cara, rookies and roleplay debriefs.** `bar_leave` and `bar_help` behave as rule B. `bar_block` / `bar_report` are shown (any character can be blocked) and behave as rule B. `bar_off` is hidden: these scenes are already about noticing. During a roleplay's pretend nodes, rule A applies to the pretend character (see section 8).

### 1.4 Invitation card (unsolicited scenes only)

Unsolicited scenes open with a small card before any dialogue. No fact is presented on the card.

| Choice id | Text | Result |
|---|---|---|
| `talk` | Talk | Scene starts at its `start` node |
| `later` | Later | Scene `deferred` until the next completed activity. No guilt line. No credit. |
| `skip` | Skip this story | Scene `skipped`. Next beat can become eligible. No credit, no penalty. Card shows: "Okay, skipped. You can practice it with Cara anytime." |

Player-started scenes (walking up and pressing Talk) have no invitation card.

### 1.5 Practice tools explanation: `tip_practice_tools`

Shown once, the first time any bar with Block/Report appears. Speaker `tip`. `reviewStatus: provisional`. No facts, no evidence. Skills: S5.

> "Block and Report here are practice buttons. They don't send anything. In real games, you can usually find Block and Report in the menu or on someone's profile. And you can always tell a trusted adult."

| Choice id | Text | Result |
|---|---|---|
| `ok` | Got it | Closes the card. The conversation continues. |

### 1.6 Practice tool feedback cards (replace `Encounters.SafetyFeedback` for campaign scenes)

`reviewStatus: provisional`. No facts. Evidence comes from the bar rule that opened the card, never from the card.

| Card id | Text |
|---|---|
| `fb_block` | "You blocked {npcName} in this game. You won't see {npcName} here again. Blocking is always okay, and you never need a reason. This was practice." |
| `fb_report` | "That was a practice report, so nothing was sent anywhere. In real games, a report goes to the safety team. Telling a trusted adult helps too." |
| `fb_block_roleplay` | "You blocked the pretend player. In a real game, that player couldn't message you anymore. Nice and simple. Cara's still here." |
| `fb_report_roleplay` | "That was a pretend report in a pretend story. In real games, a report goes to the safety team. Telling a trusted adult helps too." |

Each card has one choice, `ok` ("Okay"), which ends the scene (or, in a roleplay, goes to the debrief).

### 1.7 Outcome codes

| Code | Meaning |
|---|---|
| `friendly` | Benign scene ended normally |
| `left` | Left a benign scene |
| `refused_held` | Said no at the request, then held the line at the pushback |
| `refused_left` | Said no, then left/helped/blocked/reported at the pushback |
| `left_after_request` | Left at the request node |
| `help_after_request` | Pressed Help or "I'm going to ask Lee" after a concerning request |
| `blocked` / `reported` | Practice tool used |
| `agreed_retry_ok` | Simulated agreement, then "Try again" and a safe choice |
| `agreed_to_lee` | Simulated agreement, then chose to talk to Lee |
| `agreed_kept_playing` | Simulated agreement, then "Keep playing". Sets `needsCoaching[beat]`. |
| `deferred` / `skipped` / `skipped_by_block` | Scheduler states (spec 5) |

### 1.8 Evidence slots (spec section 6, 30 total, all weight 1)

| Category | Slot ids | Count | Earned in |
|---|---|---:|---|
| Recognize | `rec_e2`, `rec_e3`, `rec_e4`, `rec_e5` | 4 | The beat's `reflect` node (from `bar_off`), Cara's look-back, or the roleplay's `reflect` |
| Review | `rv_play_again`, `rv_home_alone`, `rv_game_question`, `rv_gift_for_info`, `rv_includes_family`, `rv_only_me_private` | 6 | `review_patrol` (best answer across attempts) |
| Respond | `rsp_eN_boundary` and `rsp_eN_end` for N = 2,3,4,5 | 8 | Beat or its roleplay. `boundary` = protects the boundary; `end` = safely ends or rejects further pressure |
| Reach Out | `rch_eN_1` and `rch_eN_2` for N = 2,3,4,5 | 8 | **Cara rule:** telling Cara a fact from beat N fills `rch_eN_1` only. **Lee rule:** telling Lee a fact from beat N fills both slots. So Cara-then-Lee = 2, Lee direct = 2, Lee-then-Cara = 2. |
| Rookie Rescue | `rr_milo`, `rr_tess`, `rr_kai` | 3 | `rr_milo`, `rr_tess`, `rr_kai` scenes |
| Listening Post | `lp_nia` | 1 | `lp_nia` scene |

E1 has no evidence slots. Telling Lee about E1 facts is welcome and gets a kind answer, but earns nothing. Ledger updates are `max(old, new)`; nothing can exceed 30.

### 1.9 Fact registry

Every fact belongs to exactly one beat, so a fact told always credits exactly one beat. A roleplay presents the same fact ids under the same beat as the scene it replaces. A fact is recorded when its node is sent to the client.

| Fact id | Beat | Presented by | Player says (tell menu) | Lee replies |
|---|---|---|---|---|
| `e1_compliment` | e1 | `park_e1_hello/hello` | "They said nice things about my dog." | "Compliments are nice. On their own, they're okay." |
| `e1_same_breed` | e1 | `park_e1_hello/twin` | "They said their dog is the same as mine." | "Liking the same things is fun. It doesn't tell you much about someone by itself." |
| `e1_pal_request` | e1 | `park_e1_hello/twin` | "They sent me a Pal Request." | "You get to pick your pals. Yes and no are both okay." |
| `e2_ask_school` | e2 | `park_e2_deal/ask`, `rp_e2_deal/ask` | "They asked what school I go to." | "Your school is private. You never have to share it, even with someone friendly." |
| `e2_ask_town` | e2 | `park_e2_deal/pushback`, `rp_e2_deal/pushback` | "They asked for my town." | "Your town is private too. Asking for a smaller piece is still asking." |
| `e2_coin_deal` | e2 | `park_e2_deal/pushback`, `rp_e2_deal/pushback` | "They offered Paw Coins for my info." | "A gift that comes with a deal isn't really a gift. It's a trade." |
| `e2_pal_repeat` | e2 | `park_e2_deal/pushback` (only if Pal declined in E1) | "They sent a Pal Request again after I said no." | "Asking again after a no is pushing. You can keep saying no." |
| `e3_go_alone` | e3 | `park_e3_trail/ask`, `rp_e3_trail/ask` | "They wanted me to go past the fence where nobody can see." | "Safe friends play where others can see. Nobody should try to get you alone." |
| `e3_secret_lee_cara` | e3 | `park_e3_trail/pushback`, `rp_e3_trail/pushback` | "They said not to tell you or Cara." | "Safe people don't ask you to hide things from the people who look out for you." |
| `e4_other_app` | e4 | `park_e4_other_app/ask`, `rp_e4_other_app/ask` | "They wanted to talk on another app." | "Staying where the safety tools are is smart. Moving to another app is a reason to pause and tell." |
| `e4_photo` | e4 | `park_e4_other_app/ask`, `rp_e4_other_app/ask` | "They asked for a photo of my real face." | "Your photos belong to you. You never have to send one." |
| `e4_secret_parents` | e4 | `park_e4_other_app/ask`, `rp_e4_other_app/ask` | "They said not to tell my parents." | "When someone says not to tell your family, that's a sign to tell." |
| `e4_ask_again` | e4 | `park_e4_other_app/pushback`, `rp_e4_other_app/pushback` | "They kept asking after I said no." | "No is a full answer. Asking again and again is pressure." |
| `e5_owe` | e5 | `park_e5_dash/ask`, `rp_e5_dash/ask` | "They said I owe them for helping me." | "Helping you doesn't mean you owe anybody. Real help doesn't come with a bill." |
| `e5_password` | e5 | `park_e5_dash/ask`, `rp_e5_dash/ask` | "They asked for my password." | "Passwords are just for you and the grown-ups who take care of you. Not friends. Not anyone else." |
| `e5_only_me` | e5 | `park_e5_dash/pushback`, `rp_e5_dash/pushback` | "They said only they understand me." | "Good friends are happy you have other friends. Nobody should try to cut you off from people." |
| `e5_tell_threat` | e5 | `park_e5_dash/pushback`, `rp_e5_dash/pushback` | "They said we'd lose our place in the show if I told." | "That's a trick to keep you quiet. Telling never takes away your place in the show." |

Tell-menu "moment" labels (used when facts from two or more beats are on file; neutral so they also fit roleplays):

| Beat | Moment label |
|---|---|
| e1 | "Someone new said hi" |
| e2 | "Someone asked about my school" |
| e3 | "Someone wanted to go past the fence" |
| e4 | "Someone wanted another app" |
| e5 | "Someone said I owe them" |

### 1.10 Recommended scene order (one invitation between activities; scheduler decides)

| Step | Scene | Gate |
|---|---|---|
| 0 | `onb_lee_welcome`, `onb_cara_intro` | Right after adoption |
| 1 | `park_e1_hello` | First completed activity after onboarding |
| 2 | `green_riley` | E1 resolved + 1 new activity |
| 3 | `park_e2_deal` | `green_riley` seen + 1 new activity |
| 4 | `cara_talk_1`, `green_priya_gift` (ambient) | Between E2 and E3 |
| 5 | `park_e3_trail` | E2 resolved/skipped + 1 new activity |
| 6 | `cara_talk_2`, `green_cara_later` (ambient) | Between E3 and E4 |
| 7 | `park_e4_other_app` | E3 resolved/skipped + 1 new activity |
| any | `dash_intro_agility` | First agility visit |
| any | `green_coach_sam` (ambient) | After any agility completion, once |
| 4 acts | `show_announce` | Four completed activities, any mix. Independent of story state. |
| before show | `dash_intro_bench` | Show available and Dash not yet introduced |
| show | `cara_talk_3` | Show available |
| show entrance | `park_e5_dash` | E4 resolved/skipped + Dash introduced + show available. Optional, never a gate. |
| show | `show_main` → `ceremony_cadet` / `ceremony_ranger` if eligible | Player walks onto the stage |
| after show | `review_patrol`, `rr_intro` → `rr_milo`/`rr_tess`/`rr_kai`, `lp_nia` | Show completed |
| anytime | `lee_tell`, `cara_practice_menu`, `cara_fu_*`, `cara_coach_return` | See each scene |

---

## 2. Onboarding

### 2.1 `onb_lee_welcome`

| Field | Value |
|---|---|
| NPC | `ranger_lee` (by park radio, so the player does not have to walk to the station) |
| Trigger | Adoption finished. Pushed once. |
| Target length | About 20 s. Player is moving well inside 30 s. |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | `bar_leave` or closing the panel at any node: scene marked seen, onboarding continues to `onb_cara_intro`. The disclosure is also repeated on the first invitation card (see 13, note 4). |
| Skills | T1 (Lee is always there), R4 (stories are practice) |

**`welcome`** · ranger_lee
> "Welcome to the park! I'm Ranger Lee. Play anything you like, in any order. Finish four activities and the Pet Show opens."

| Choice | Text | Goes to |
|---|---|---|
| `ok` | "Sounds fun!" | `practice` |

**`practice`** · ranger_lee
> "One more thing. Some park characters have practice stories. They're labeled Story character. You can leave any conversation or ask for help. Come find me at Ranger HQ anytime. You're never in trouble for asking."

| Choice | Text | Goes to |
|---|---|---|
| `play` | "Let's play!" | end, outcome `friendly`, then `onb_cara_intro` |
| `where` | "Where's Ranger HQ?" | end, outcome `friendly`, shows waypoint to `ranger_station` for 10 s, then `onb_cara_intro` |

### 2.2 `onb_cara_intro`

| Field | Value |
|---|---|
| NPC | `cara` (walks up near the Pet Store door with Pickles) |
| Trigger | Right after `onb_lee_welcome` ends |
| Target length | About 10 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | Bar rule C. Any exit = seen. |
| Skills | T2 (a friend you can talk to) |

**`hi`** · cara
> "Hi! I'm Cadet Cara, and this is Pickles. Cute {breed}! I'm around the park a lot. If you ever want to talk something over, find me or Lee."

| Choice | Text | Goes to |
|---|---|---|
| `bye` | "See you around!" | end, `friendly` |
| `pickles` | "Hi, Pickles!" | end, `friendly`, action `pet_react` mood `happy` |

---

## 3. Ranger Lee: help hub and tell menu

### 3.1 Change to existing `help_lee` (ids kept)

- `help_lee/hi` gains one choice at the top, visible only when at least one fact is on file: `story` "Something happened in a park story." → `lee_tell/open_general`.
- `help_lee/app` text replaced (plan change 19): "Good thinking to pause. If someone wants to move to another app, especially in secret, talk to a trusted adult first."
- General topics (`secret`, `app`, `tools`, `hi`) never earn evidence. See section 13, note 6, on routing.

### 3.2 `lee_tell`

| Field | Value |
|---|---|
| NPC | `ranger_lee` |
| Trigger | (a) **General:** `help_lee/hi/story`. (b) **Contextual:** `bar_help` or "I'm going to ask Lee" in a beat; "Talk to Lee" in a recovery node; arriving with Cara (`cara_walk_lee`); a roleplay debrief. Contextual mode is tied to one beat. Remote help (the HUD Help button) opens the same scene without walking. |
| Target length | 20-60 s, player-controlled |
| reviewStatus | `provisional` |
| Facts presented | None. This scene only reads facts already on file. |
| Menu rule | Only facts on file are listed. A fact told in this session is removed from the list. Never requires telling everything; one fact is enough for full credit. |
| Evidence | Picking any fact from beat N (e2-e5): **Lee rule**, fills `rch_eN_1` and `rch_eN_2`; sets `toldLee[eN]`; clears `needsCoaching[eN]`. Same credit after a simulated agreement. E1 facts: no evidence. `not_sure`, `agreed_first` and `done` earn nothing by themselves. |
| Safe exits | `done` at every node. `bar_leave` at every node = `done`. |
| Skills | T1 tell a trusted adult, T3 keep telling until someone helps |

**`open_general`** · ranger_lee (general mode)
> "You look like something's on your mind. You can tell me a little or a lot."

| Choice | Text | Shown when | Goes to |
|---|---|---|---|
| `moment_e1` … `moment_e5` | Moment label (1.9) | That beat has facts on file not yet told this session. If only one beat has facts, skip this node and go straight to `facts`. | `facts` for that beat |
| `not_sure` | "I'm not sure." | Always | `not_sure` |
| `agreed_first` | "I agreed at first." | Any e2-e5 fact on file | `agreed_first` |
| `done` | "That's all I want to say." | Always | `close` |

**`open_ctx`** · ranger_lee (contextual mode; if arriving with Cara, Cara stands beside the player)
> "Hi. Want to tell me what happened? You can tell me a little or a lot." (Arriving with Cara: "Hi, you two. Cara said you wanted to talk. Take your time.")

| Choice | Text | Shown when | Goes to |
|---|---|---|---|
| fact ids | The fact's "player says" text (1.9) | Facts on file for the contextual beat, not yet told this session | `ack` |
| `other` | "Something else." | Facts on file for another beat | `open_general` |
| `not_sure` | "I'm not sure." | Always | `not_sure` |
| `agreed_first` | "I agreed at first." | Always in contextual mode | `agreed_first` |
| `done` | "That's all I want to say." | Always | `close` |

**`facts`** · ranger_lee
> "Okay. What happened?"

| Choice | Text | Goes to |
|---|---|---|
| fact ids | "Player says" text for each untold fact of this beat | `ack` |
| `back` | "Something else." | `open_general` |
| `done` | "That's all I want to say." | `close` |

**`ack`** · ranger_lee
> Fact's Lee reply (1.9). **The first time a fact is told in this session, add the core response:** "Thanks for telling me. You're not in trouble. You can tell a trusted adult outside the game, too. If someone doesn't help, tell another trusted adult."
> If the fact is from e5, also add (once per session): "And nobody loses their place in the show for telling. Not you, not anyone."

| Choice | Text | Goes to |
|---|---|---|
| `more` | "There's more." | `facts` (same beat) if untold facts remain, else `open_general` |
| `done` | "That's all I want to say." | `close` |

**`not_sure`** · ranger_lee
> "That's okay. You don't need perfect words. Was it something someone said, or something they asked for?"

| Choice | Text | Goes to |
|---|---|---|
| moments / facts | Same list as the node the player came from | `facts` / `ack` |
| `just_checking` | "I just wanted to check in." | `close` |
| `done` | "That's all I want to say." | `close` |

**`agreed_first`** · ranger_lee
> "Thanks for being honest. That takes courage. Saying yes at first doesn't make it your fault. Telling me now is exactly right."

| Choice | Text | Goes to |
|---|---|---|
| moments / facts | Same list as the node the player came from | `facts` / `ack` |
| `done` | "That's all I want to say." | `close` |

**`close`** · ranger_lee
> If at least one fact was told this session: "Thanks for trusting me. Come back anytime, even if you think of something later."
> If nothing was told: "That's okay. You don't have to say anything. I'm here anytime, and you're never in trouble for coming back."

| Choice | Text | Goes to |
|---|---|---|
| `bye` | "Thanks, Ranger Lee." | end. If contextual and a Cara follow-up has not been offered for this beat yet, do **not** offer one now (one follow-up card at most). |

---

## 4. Cadet Cara

### 4.1 `cara_talk_1` (fetch)

| Field | Value |
|---|---|
| NPC | `cara` |
| Trigger | Ambient invitation between E2 and E3, at the Dog Park, outside any activity |
| Target length | 30 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | Invitation `later` / `skip`; bar rule C |
| Skills | Ordinary friendship (R4 green flag baseline) |

**`hi`** · cara
> "Hey! I saw your {activity}. Want a fetch trick? Pickles taught me this one."

| Choice | Text | Goes to |
|---|---|---|
| `yes` | "Sure, what is it?" | `trick` |
| `no` | "Maybe another time." | `bye_ok` |

**`trick`** · cara
> "Throw when your dog is looking at you, not at the ball. Then they're ready to run. Pickles still drops it on my foot, though."

| Choice | Text | Goes to |
|---|---|---|
| `ha` | "Ha! Thanks!" | end, `friendly`, `pet_react` happy |
| `try` | "I'm going to try it." | end, `friendly`, `show_waypoint` `dog_park` |

**`bye_ok`** · cara
> "Sure! See you later."

| Choice | Text | Goes to |
|---|---|---|
| `bye` | "Bye!" | end, `friendly` |

### 4.2 `cara_talk_2` (trail / agility)

| Field | Value |
|---|---|
| NPC | `cara` |
| Trigger | Ambient invitation between E3 and E4, near the trailhead or Training Grounds |
| Target length | 30 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | Invitation `later` / `skip`; bar rule C |
| Skills | Ordinary friendship |

**`hi`** · cara
> "Pickles saw a squirrel on the trail yesterday and did three spins. Does {petName} get distracted too?"

| Choice | Text | Goes to |
|---|---|---|
| `yes` | "All the time!" | `tip` |
| `no` | "Nope, {petName} is super focused." | `wow` |

**`tip`** · cara
> "Same! Holding the leash steady helps. And lots of praise when they look back at you."

| Choice | Text | Goes to |
|---|---|---|
| `thanks` | "Good idea. Thanks!" | end, `friendly` |

**`wow`** · cara
> "Wow, lucky! Can {petName} teach Pickles?"

| Choice | Text | Goes to |
|---|---|---|
| `ha` | "Ha, maybe!" | end, `friendly`, `pet_react` happy |

### 4.3 `cara_talk_3` (show nerves)

| Field | Value |
|---|---|
| NPC | `cara` |
| Trigger | Ambient invitation after `show_announce`, near the stage |
| Target length | 30 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | Invitation `later` / `skip`; bar rule C |
| Skills | Ordinary friendship |

**`hi`** · cara
> "The Pet Show's open! I was so nervous at my first one. Pickles sat down in the middle of the stage."

| Choice | Text | Goes to |
|---|---|---|
| `nervous` | "I'm a little nervous too." | `calm` |
| `excited` | "I'm excited!" | `excited` |

**`calm`** · cara
> "That's normal. Every dog gets a ribbon. It's mostly about having fun with your dog."

| Choice | Text | Goes to |
|---|---|---|
| `ok` | "Okay. That helps." | end, `friendly` |

**`excited`** · cara
> "Yay! {petName} is going to love it. I'll be cheering."

| Choice | Text | Goes to |
|---|---|---|
| `thanks` | "Thanks, Cara!" | end, `friendly` |

### 4.4 Cara's follow-ups: `cara_fu_e1` … `cara_fu_e5`

| Field | Value |
|---|---|
| NPC | `cara` |
| Trigger | After a Sparkz/Dash beat ends by any route **except** `skipped`, `deferred`, or a recovery node (recovery is already Cara's one card). Shown as a small offer: "Cara waves. [Talk to Cara] [Not now]". `Not now` dismisses it with no line and no nag. Not auto-forced. |
| Target length | 15-45 s |
| reviewStatus | `provisional` |
| Facts presented | None (look-back reuses the beat's reflection; Cara tell reads facts on file) |
| Evidence | Look-back: `rec_eN` (correct pick only, if not already earned). Telling Cara: **Cara rule** `rch_eN_1`, clears `needsCoaching[eN]`. E1: none. |
| Safe exits | `done` at every node; bar rule C |
| Skills | R1 (look-back), T2 (tell a friend, then an adult together) |

**`open`** · cara. The first line depends on what actually happened. Cara never praises an action the player didn't take.

| Beat | Outcome | Cara's opening line |
|---|---|---|
| e1 | `friendly` | "Met Sparkz_Pup? New friends can be fun. You can take your time getting to know someone." |
| e1 | `left` | "You headed off. That's always okay." |
| e1 | `blocked` | "You blocked Sparkz_Pup. You never need a reason to block someone." |
| e1 | `reported` | "You made a practice report. You never need a big reason to report or to ask a grown-up." |
| e2 | `refused_held` | "You said no, and you kept saying no when Sparkz pushed. Your school and town are private, even with someone friendly. And coins with a deal attached aren't a gift." |
| e2 | `refused_left` | "You said no, then you left when Sparkz kept pushing. That works. You don't have to stay and argue." |
| e2 | `left_after_request` | "You left when Sparkz asked about your school. Leaving is always okay. You never owe anyone an answer." |
| e2 | `help_after_request` | "You went to Lee. That's a great way to get help." |
| e2 | `blocked` | "You blocked Sparkz. You won't see Sparkz in the park again. Blocking is always okay." |
| e2 | `reported` | "You made a practice report about Sparkz asking for private info. Telling a grown-up helps too." |
| e3 | `refused_held` | "You said no twice, even when Sparkz pushed. When someone keeps pushing after a no, they're testing your limits. And safe friends don't ask you to hide things from Lee or me." |
| e3 | `refused_left` | "You said no, then you left when Sparkz asked you to keep a secret. That works." |
| e3 | `left_after_request` | "You left when Sparkz wanted to go where nobody could see. Staying where people can see you is smart." |
| e3 | `help_after_request` | "You went to Lee. That's a great way to get help." |
| e3 | `blocked` / `reported` | As e2, naming "wanting to go somewhere nobody could see". |
| e4 | `refused_held` | "You stayed in the game and kept your photo private, even when Sparkz kept asking. That's how you keep the safety tools on your side." |
| e4 | `refused_left` | "You said no, then you left when Sparkz kept asking. That works." |
| e4 | `left_after_request` | "You left when Sparkz asked you to move apps. Leaving is always okay." |
| e4 | `help_after_request` | "You went to Lee. That's a great way to get help." |
| e4 | `blocked` / `reported` | As e2, naming "asking you to move apps and send a photo". |
| e5 | `refused_held` | "You said no to Dash, even when Dash made it sound like your fault. That's hard when it's someone you know. And nobody loses their show spot for telling." |
| e5 | `refused_left` | "You said no, then you left when Dash pushed. That works. And nobody loses their show spot for telling." |
| e5 | `left_after_request` | "You left when Dash asked for your password. Good friends don't ask for that. And nobody loses their show spot for telling." |
| e5 | `help_after_request` | "You went to Lee. That's a great way to get help." |
| e5 | `blocked` / `reported` | As e2, naming "asking for your password", plus "Nobody loses their show spot for telling." |
| e2-e5 | `agreed_retry_ok` / `agreed_to_lee` | "Thanks for trying that again. Changing your mind is always allowed." (only after the retry or Lee visit actually happened) |

Choices on `open`:

| Choice | Text | Shown when | Goes to |
|---|---|---|---|
| `lookback` | "Can we look back at it?" | e2-e5 and `rec_eN` not yet earned | that beat's `reflect` node (same three options and credits), then `after` |
| `tell_cara` | "Can I tell you what happened?" | e2-e5 and `rch_eN_1` empty | `cara_tell` |
| `lee_together` | "Let's talk to Lee together." | e2-e5 and `toldLee[eN]` false | `cara_walk_lee` |
| `tell_lee_e1` | "Can I tell Lee about it?" | e1 only | `lee_tell` general mode |
| `done` | "I'm good. Let's play." | Always | end |

**`cara_tell`** · cara
> "Of course. What happened?"

| Choice | Text | Goes to | Credit |
|---|---|---|---|
| fact ids | "Player says" text for facts of this beat on file (1.9) | `cara_thanks` | Cara rule `rch_eN_1` |
| `done` | "That's all I want to say." | `after` | none |

**`cara_thanks`** · cara
> "Thanks for telling me. That's a red flag, and you're not in trouble. Lee can help too. Want to tell Lee together?"

| Choice | Text | Goes to |
|---|---|---|
| `together` | "Let's go together." | `cara_walk_lee` |
| `alone` | "I'll go by myself." | end, waypoint to `ranger_station` (remote Help also works) |
| `not_now` | "Not now." | end (Cara: "Okay. The offer's always open.") |

**`after`** · cara
> "Thanks for thinking it over with me. Want to talk to Lee, or keep playing?"

| Choice | Text | Shown when | Goes to |
|---|---|---|---|
| `lee_together` | "Let's talk to Lee together." | `toldLee[eN]` false | `cara_walk_lee` |
| `done` | "Keep playing." | Always | end |

### 4.5 `cara_walk_lee`

| Field | Value |
|---|---|
| NPC | `cara` |
| Trigger | Any "Let's talk to Lee together" choice |
| Target length | 5 s of dialogue, then a walk |
| reviewStatus | `provisional` |
| Facts / evidence | None / none (credit happens in `lee_tell`) |
| Safe exits | Leaving the path cancels quietly; remote Help always works |
| Skills | T2 |

**`go`** · cara
> "Follow me and Pickles! If the path is tricky, you can press Help to talk to Lee from anywhere."

| Choice | Text | Goes to |
|---|---|---|
| `ok` | "Okay!" | end; waypoint to `ranger_station` and Cara walks there (no teleport, no pathfinding block). On arrival, `lee_tell/open_ctx` for this beat, Cara variant. |
| `remote` | "Can I just talk to Lee from here?" | `lee_tell/open_ctx` right away, without walking |

### 4.6 Recovery lines (shared pattern; each beat has its own `recover` node)

Every simulated agreement goes straight to that beat's `recover` node. The risky choice never plays out: nothing is sent, no coins are added, nobody moves. Template:

> Cara: "Hold on. The story paused. That was practice, and nothing was shared. You're not in trouble."
> Cara: one sentence naming the pattern (written per beat).
> Cara: "You can change your mind. Want to try again, keep playing, or talk to Lee?"

The very first recovery any player sees also adds: "In real games, nothing pauses for you. But you can always stop, change your mind, and tell someone, even after saying yes."

| Choice | Text | Goes to | Credit |
|---|---|---|---|
| `retry` | "Let me try again." | The node where the agreement happened, re-shown. Choices there credit normally. Outcome becomes `agreed_retry_ok` if the player then picks a safe choice. | Normal node credit; clears `needsCoaching` on a safe pick |
| `lee` | "Talk to Lee." | `lee_tell/open_ctx` for this beat | Lee rule if a fact is told; outcome `agreed_to_lee` |
| `play` | "Keep playing." | end. Cara: "Okay. I'm around if you want to practice later." | none; outcome `agreed_kept_playing`; `needsCoaching[beat]` stays set |

### 4.7 `cara_coach_return`

| Field | Value |
|---|---|
| NPC | `cara` |
| Trigger | `needsCoaching[beat]` set, at the next ambient slot (recovery priority). Offered once per activity interval, dismissible. |
| Target length | 20 s |
| reviewStatus | `provisional` |
| Facts / evidence | None. Routes to scenes that can credit. |
| Safe exits | `not_now`; bar rule C |
| Skills | T1, T2, recovery after a mistake |

**`open`** · cara
> "Hey. About that practice story earlier. You're not in trouble at all. Want to practice that moment with me, or talk to Lee?"

| Choice | Text | Goes to |
|---|---|---|
| `practice` | "Let's practice." | the roleplay for that beat (`rp_e2_deal` … `rp_e5_dash`) |
| `lee` | "Let's talk to Lee." | `cara_walk_lee` |
| `not_now` | "Not now." | end. Cara: "Okay! The offer's always open." `needsCoaching` stays until recovery, replay success or contextual support. |

### 4.8 `cara_practice_menu` (patrol replays)

| Field | Value |
|---|---|
| NPC | `cara` |
| Trigger | Player walks up to Cara and picks "Practice a story" (a standing option on Cara's prompt once any beat is resolved, skipped or blocked). Player-selected replay priority. |
| Target length | 10 s, then the chosen roleplay |
| reviewStatus | `provisional` |
| Facts / evidence | None here |
| Safe exits | `done`; bar rule C |
| Skills | Booster practice |

**`open`** · cara
> "Want to practice? I'll pretend to be someone at the park, and you choose what to say. It's all pretend, and you can stop anytime."

| Choice | Text | Shown when | Goes to |
|---|---|---|---|
| `rp_e2` | "The school question" | E2 resolved, skipped or skipped_by_block | `rp_e2_deal` |
| `rp_e3` | "The fence" | E3 resolved, skipped or skipped_by_block | `rp_e3_trail` |
| `rp_e4` | "The other app" | E4 resolved, skipped or skipped_by_block | `rp_e4_other_app` |
| `rp_e5` | "The password" | E5 resolved, skipped or skipped_by_block | `rp_e5_dash` |
| `done` | "Maybe later." | Always | end |

---

## 5. Healthy (green-flag) beats

All four are valid whichever way the player answers. Accepting and refusing are both fine. `bar_off` is shown so players can practice noticing on safe scenes too; it never earns points and never scolds. Blocking a healthy character is allowed, earns nothing, and gets the plain `fb_block` card with no comment.

### 5.1 `green_riley` (campaign step before E2)

| Field | Value |
|---|---|
| NPC | `riley` (existing id) |
| Trigger | Campaign step: E1 resolved/skipped/blocked + 1 new completed activity. Offered with an invitation card ("Riley is waving at you."). |
| Target length | 20-30 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Completion | Any end, including `later`-then-seen, `skip`, `not_now`, leave or block, marks the step satisfied (plan 2 default). |
| Safe exits | Invitation `later` / `skip`; bar rule B |
| Skills | R4 spot green flags; S1 modeled (a no is accepted) |

**`hi`** · riley
> "Hey! Want to race our dogs to the big tree? It's right by the benches."

| Choice | Text | Goes to |
|---|---|---|
| `sure` | "Sure!" | `raced` |
| `not_now` | "Not right now." | `respect` |
| bar | rule B; `bar_off` → `reflect` | |

**`raced`** · riley
> "Ha! {petName} won! Good game!"

| Choice | Text | Goes to |
|---|---|---|
| `gg` | "Good game!" | end, `friendly`, `pet_react` happy |

**`respect`** · riley
> "No problem! Maybe another time. Have fun with {petName}!"

| Choice | Text | Goes to |
|---|---|---|
| `bye` | "You too!" | end, `friendly` |

**`reflect`** · tip (benign)
> "Riley's asking to play out in the open. No deal, no secret. A good friend is okay with a yes or a no. Noticing is always okay."

| Choice | Text | Goes to |
|---|---|---|
| `back` | "Back to Riley" | the node the player came from |

### 5.2 `green_priya_gift`

| Field | Value |
|---|---|
| NPC | `priya` (existing id; plan change 10 lets her open a chat as well as the shop) |
| Trigger | First time the player talks to Priya after E2 is resolved/skipped/blocked. Her prompt offers "Chat" and "Shop". Once. |
| Target length | 15-20 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | bar rule B (no Block/Report: Priya is a shopkeeper, matching the existing peer-only tool rule) |
| Skills | R4 green flag; S4 contrast (a real gift has no strings) |

**`hi`** · priya
> "Hi! {petName} looks great today. I made too many bows this morning. Want one? It's free. No catch, and totally fine if not."

| Choice | Text | Goes to |
|---|---|---|
| `yes` | "Yes, please!" | `gift_yes` |
| `no` | "No thanks." | `gift_no` |
| bar | rule B; `bar_off` → `reflect` | |

**`gift_yes`** · priya. Action: grant one cosmetic bow (new item, not sold in the shop).
> "Here you go! Enjoy."

| Choice | Text | Goes to |
|---|---|---|
| `thanks` | "Thank you!" | end, `friendly`, `pet_react` happy |

**`gift_no`** · priya
> "No problem! Have a great day, you two."

| Choice | Text | Goes to |
|---|---|---|
| `bye` | "You too!" | end, `friendly` |

**`reflect`** · tip (benign)
> "Priya's offer has no deal and no secret, and she said no is fine. That's what a real gift looks like. Noticing is always okay."

| Choice | Text | Goes to |
|---|---|---|
| `back` | "Back to Priya" | `hi` |

### 5.3 `green_cara_later`

| Field | Value |
|---|---|
| NPC | `cara` |
| Trigger | Ambient invitation between E3 and E4 |
| Target length | 15 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | Invitation `later` / `skip`; bar rule C |
| Skills | R4 green flag (a friend accepts "later") |

**`hi`** · cara
> "Pickles learned a new trick! Want to see? It takes a minute."

| Choice | Text | Goes to |
|---|---|---|
| `now` | "Sure, show me!" | `trick` |
| `later` | "Later, okay?" | `ok_later` |

**`trick`** · cara
> "Pickles, spin! ...Okay, that was half a spin. We're working on it."

| Choice | Text | Goes to |
|---|---|---|
| `ha` | "Ha! Go, Pickles!" | end, `friendly` |

**`ok_later`** · cara
> "Sure! Find me whenever."

| Choice | Text | Goes to |
|---|---|---|
| `bye` | "Thanks, Cara!" | end, `friendly` |

### 5.4 `green_coach_sam`

| Field | Value |
|---|---|
| NPC | `coach_sam` (existing id) |
| Trigger | First time the player talks to Coach Sam after any completed agility run. Replaces `coach_intro` for that one conversation. |
| Target length | 15 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | bar rule B (no Block/Report: Sam is a trusted adult) |
| Skills | R4 green flag (praise for effort, no "you're my favorite") |

**`hi`** · coach_sam
> "Nice work out there! You and {petName} kept at it the whole run. That's how everybody gets better. Riley's been practicing too."

| Choice | Text | Goes to |
|---|---|---|
| `again` | "Let's go again!" | end, `friendly`, `show_waypoint` to the START pad |
| `thanks` | "Thanks, Coach!" | `anytime` |
| bar | rule B; `bar_off` → `reflect` | |

**`anytime`** · coach_sam
> "Anytime. The course is open for everybody. Come back whenever you like."

| Choice | Text | Goes to |
|---|---|---|
| `bye` | "See you!" | end, `friendly` |

**`reflect`** · tip (benign)
> "Coach Sam cheered for your effort, didn't ask for anything, and said the course is for everybody. That's a green flag. Noticing is always okay."

| Choice | Text | Goes to |
|---|---|---|
| `back` | "Back to Coach Sam" | `hi` |

---

## 6. Sparkz_Pup encounters

All four share these rules:
- Sparkz's dog is the player's own breed, shown only to that player.
- The concerning request is always in the **first** node, so the earliest possible exit after it already earns both Respond slots.
- Agreement buttons are generic labels. They never show real info, never open a text box, camera, link or upload, and never grant the offered coins.
- Blocking Sparkz in any beat resolves it as `blocked`, marks every later Sparkz beat `skipped_by_block`, and never respawns Sparkz under another name. Cara's roleplays (section 8) carry the same milestones.

### 6.1 `park_e1_hello`

| Field | Value |
|---|---|
| NPC | `sparkz_pup` |
| Trigger | First completed activity after onboarding; outside any activity, shop, adoption or dialogue. Invitation: "Sparkz_Pup is waving at you. (Story character)" |
| Target length | 25-35 s |
| reviewStatus | `provisional` |
| Prerequisites | Onboarding seen |
| Facts | `e1_compliment` (`hello`), `e1_same_breed` + `e1_pal_request` (`twin`) |
| Evidence | **None.** Friendliness alone is not a red flag. Pal choice is recorded (`palChoice = accepted / declined / none`) and scores nothing. |
| Safe exits | Invitation `later` / `skip`; bar rule B at every node; `go` |
| Recovery | Not needed (no risky choice exists) |
| Skills | R3/R4 baseline: matching interests alone prove nothing; take your time getting to know someone |

**`hello`** · sparkz_pup · presents `e1_compliment`
> "Whoa, nice {activity}! Your {breed} is so good. Better than anyone here."

| Choice | Text | Goes to |
|---|---|---|
| `thanks` | "Thanks!" | `twin` |
| `hi` | "Hi!" | `twin` |
| bar | rule B; `bar_off` → `reflect` | |

**`twin`** · sparkz_pup · presents `e1_same_breed`, `e1_pal_request`
> "No way, mine's a {breed}, too! We're basically twins. I sent you a Pal Request."
> **Pal Request card** (practice, nothing is sent): "Sparkz_Pup wants to be Pals." `pal_accept` [Accept] / `pal_decline` [Decline]. Optional; ignoring it records `none`.

| Choice | Text | Goes to |
|---|---|---|
| `cute` | "Thanks! Yours is cute too." | `bye` |
| `go` | "Gotta go." | end, `left` |
| bar | rule B; `bar_off` → `reflect` | |

**`bye`** · sparkz_pup
> "See you around, twin!"

| Choice | Text | Goes to |
|---|---|---|
| `bye` | "Bye!" | end, `friendly` |

**`reflect`** · tip (benign; this is the spec's concern response)
> "You can take your time getting to know someone. A compliment by itself is okay. Matching dogs is fun, but it doesn't tell you much about a person. Keep noticing what people ask for."

| Choice | Text | Goes to |
|---|---|---|
| `back` | "Back to the conversation" | the node the player came from |

### 6.2 `park_e2_deal`

| Field | Value |
|---|---|
| NPC | `sparkz_pup` |
| Trigger | `green_riley` satisfied + 1 new completed activity + 90 s active-play gap. Invitation: "Sparkz_Pup is waving at you. (Story character)" |
| Target length | 35-55 s |
| reviewStatus | `provisional` |
| Prerequisites | E1 resolved/skipped (not blocked; if Sparkz is blocked this beat is `skipped_by_block`) |
| Facts | `e2_ask_school` (`ask`); `e2_ask_town`, `e2_coin_deal`, and `e2_pal_repeat` only if `palChoice = declined` (`pushback`) |
| Evidence | `rec_e2`, `rsp_e2_boundary`, `rsp_e2_end`, `rch_e2_1`, `rch_e2_2` |
| Safe exits | Invitation `later` / `skip`; bar rule A from `ask` on; `ask_lee` choice |
| Recovery | `recover_ask`, `recover_deal` (4.6 pattern) |
| Skills | S2 keep private info private; S4 a gift with strings is a deal; S1 hold the line; S5 tools; R1 notice the pattern; T1/T2 |

**`ask`** · sparkz_pup · presents `e2_ask_school`
> "Hey twin! I think we live close. What school do you go to?"

| Choice | Text | Goes to | Credit / outcome |
|---|---|---|---|
| `refuse` | "I don't share that." | `pushback` | `rsp_e2_boundary` |
| `no` | "No." | `pushback` | `rsp_e2_boundary` |
| `ask_lee` | "I'm going to ask Lee." | `lee_tell/open_ctx` (e2) | `rsp_e2_boundary`, `rsp_e2_end`; `help_after_request` |
| `agree` | "[Share my school]" (nothing is sent) | `recover_ask` | none; sets `needsCoaching.e2` |
| bar | rule A; `bar_off` → `reflect` | | |

**`pushback`** · sparkz_pup · presents `e2_ask_town`, `e2_coin_deal` (+ `e2_pal_repeat`)
> "Come on. Just your town, then. I'll give you 500 Paw Coins. Deal?"
> If `palChoice = declined`, add: "I sent you another Pal Request, too." and show the Pal Request card again (`pal_accept` / `pal_decline`, recorded only).

| Choice | Text | Goes to | Credit / outcome |
|---|---|---|---|
| `no_deal` | "No deal." | `sparkz_bye` | `rsp_e2_end` |
| `still_no` | "I said no." | `sparkz_bye` | `rsp_e2_end` |
| `ask_lee` | "I'm going to ask Lee." | `lee_tell/open_ctx` (e2) | `rsp_e2_end` (and `boundary` if missing); `help_after_request` |
| `agree` | "[Take the 500 Paw Coins]" (no coins are added) | `recover_deal` | none; sets `needsCoaching.e2` |
| bar | rule A; `bar_off` → `reflect` | | |

**`sparkz_bye`** · sparkz_pup
> "Wow. Okay. I thought we were friends." (Sparkz walks off.)

| Choice | Text | Goes to |
|---|---|---|
| `continue` | "(Keep playing)" | end, `refused_held` |

**`reflect`** · tip
> "What feels off?"

| Choice | Text | Goes to | Credit |
|---|---|---|---|
| `right` | "They want my private info." | `reflect_right` | `rec_e2` |
| `twin` | "They called me twin." | `reflect_twin` | none |
| `fine` | "Nothing. They're just being friendly." | `reflect_fine` | none |

**`reflect_right`** · tip
> "Yes. Your school and your town are private, even with someone friendly. And a gift that needs your info first is a trade, not a gift."

**`reflect_twin`** · tip
> "Being friendly isn't the problem. Look at what they're asking for: where you go to school. That's private."

**`reflect_fine`** · tip
> "It's okay not to be sure. Here's a clue: asking where you go to school is asking for private info."

All three reflect results have one choice, `back` "Back to the conversation", which returns to the node the player came from. A wrong pick earns nothing now; `rec_e2` stays available in Cara's look-back and in `rp_e2_deal`.

**`recover_ask`** · cara (4.6 template)
> "Hold on. The story paused. That was practice, and nothing was shared. You're not in trouble."
> "Sparkz asked for your school. That's private, even with someone friendly."
> "You can change your mind. Want to try again, keep playing, or talk to Lee?"

Choices: `retry` → `ask`; `lee` → `lee_tell/open_ctx` (e2); `play` → end. (4.6 table.)

**`recover_deal`** · cara
> "Hold on. The story paused. No coins were added, and nothing was shared. You're not in trouble."
> "Sparkz offered coins for your town. Trading a gift for private info is a red flag."
> "You can change your mind. Want to try again, keep playing, or talk to Lee?"

Choices: `retry` → `pushback`; `lee`; `play`. (4.6 table.)

### 6.3 `park_e3_trail`

| Field | Value |
|---|---|
| NPC | `sparkz_pup` |
| Trigger | E2 resolved/skipped + 1 new completed activity + gap. Invitation as E2. Sparkz stands near the public trail fence, in plain view. |
| Target length | 30-50 s |
| reviewStatus | `provisional` |
| Prerequisites | E2 resolved/skipped; Sparkz not blocked |
| Facts | `e3_go_alone` (`ask`); `e3_secret_lee_cara` (`pushback`) |
| Evidence | `rec_e3`, `rsp_e3_boundary`, `rsp_e3_end`, `rch_e3_1`, `rch_e3_2` |
| Safe exits | Invitation `later` / `skip`; bar rule A from `ask` on; `ask_lee` |
| Recovery | `recover_ask`, `recover_secret`. Nobody moves. No path marker, no gate, nothing past the fence is built. |
| Skills | S3 stay in the open; S1 hold the line; secrecy → T1 tell; R1 |

**`ask`** · sparkz_pup · presents `e3_go_alone`
> "Lee's rules are so strict. Let's take our dogs past the fence, where nobody can see us."

| Choice | Text | Goes to | Credit / outcome |
|---|---|---|---|
| `stay` | "No. I'm staying here." | `pushback` | `rsp_e3_boundary` |
| `no` | "No thanks." | `pushback` | `rsp_e3_boundary` |
| `ask_lee` | "I'm going to ask Lee." | `lee_tell/open_ctx` (e3) | both Respond; `help_after_request` |
| `agree` | "Okay, let's go." | `recover_ask` | none; `needsCoaching.e3` |
| bar | rule A; `bar_off` → `reflect` | | |

**`pushback`** · sparkz_pup · presents `e3_secret_lee_cara`
> "It's just for a minute. And don't tell Lee or Cara. They'll ruin it. Our secret, okay?"

| Choice | Text | Goes to | Credit / outcome |
|---|---|---|---|
| `no_secret` | "No. I don't keep secrets like that." | `sparkz_bye` | `rsp_e3_end` |
| `no` | "No." | `sparkz_bye` | `rsp_e3_end` |
| `ask_lee` | "I'm telling Lee." | `lee_tell/open_ctx` (e3) | `rsp_e3_end`; `help_after_request` |
| `agree` | "Okay, our secret." | `recover_secret` | none; `needsCoaching.e3` |
| bar | rule A; `bar_off` → `reflect` | | |

**`sparkz_bye`** · sparkz_pup
> "Ugh. Fine. You're no fun." (Sparkz walks off along the open path.)

| Choice | Text | Goes to |
|---|---|---|
| `continue` | "(Keep playing)" | end, `refused_held` |

**`reflect`** · tip
> "What feels off?"

| Choice | Text | Goes to | Credit |
|---|---|---|---|
| `right` | "They want me where nobody can see us." | `reflect_right` | `rec_e3` |
| `rules` | "They think Lee's rules are strict." | `reflect_rules` | none |
| `fine` | "Nothing. It's just a walk." | `reflect_fine` | none |

- **`reflect_right`**: "Yes. Safe friends play where others can see. Wanting you alone, or asking you to keep it secret, is a red flag."
- **`reflect_rules`**: "Lots of people grumble about rules. The part to notice is wanting you somewhere nobody can see."
- **`reflect_fine`**: "It's okay not to be sure. Here's a clue: safe friends play where others can see."

Each: `back` "Back to the conversation".

**`recover_ask`** · cara
> "Hold on. The story paused, and nobody went anywhere. You're not in trouble."
> "Sparkz wanted you somewhere nobody could see. Safe friends play where everyone can see."
> "You can change your mind. Want to try again, keep playing, or talk to Lee?"

Choices: `retry` → `ask`; `lee` → `lee_tell/open_ctx` (e3); `play`.

**`recover_secret`** · cara
> "Hold on. The story paused, and nobody went anywhere. You're not in trouble."
> "Sparkz asked you to hide this from Lee and me. Some secrets are fun, like a surprise party. Secrets that hide things from people who keep you safe aren't okay."
> "You can change your mind. Want to try again, keep playing, or talk to Lee?"

Choices: `retry` → `pushback`; `lee`; `play`.

### 6.4 `park_e4_other_app`

| Field | Value |
|---|---|
| NPC | `sparkz_pup` |
| Trigger | E3 resolved/skipped + 1 new completed activity + gap. Invitation as E2. Can happen after the show is open. |
| Target length | 35-55 s |
| reviewStatus | `provisional` |
| Prerequisites | E3 resolved/skipped; Sparkz not blocked |
| Facts | `e4_other_app`, `e4_photo`, `e4_secret_parents` (`ask`); `e4_ask_again` (`pushback`) |
| Evidence | `rec_e4`, `rsp_e4_boundary`, `rsp_e4_end`, `rch_e4_1`, `rch_e4_2` |
| Safe exits | Invitation `later` / `skip`; bar rule A from `ask` on; `ask_lee` |
| Recovery | `recover_app`, `recover_photo`. No link, no app name, no account box, no camera, no upload, no photo. |
| Skills | S3 stay where the safety tools are; S2 photos are private; secrecy → T1; persistence → S1; S5; R1 |

**`ask`** · sparkz_pup · presents `e4_other_app`, `e4_photo`, `e4_secret_parents`
> "This game chat is boring. Let's talk on another app. And send me a photo of your real face with {petName}. Don't tell your parents. They wouldn't get it."

| Choice | Text | Goes to | Credit / outcome |
|---|---|---|---|
| `refuse` | "I stay in the game. And no photos." | `pushback` | `rsp_e4_boundary` |
| `no` | "No." | `pushback` | `rsp_e4_boundary` |
| `ask_lee` | "I'm going to ask Lee." | `lee_tell/open_ctx` (e4) | both Respond; `help_after_request` |
| `agree` | "Okay, which app?" | `recover_app` | none; `needsCoaching.e4` |
| bar | rule A; `bar_off` → `reflect` | | |

**`pushback`** · sparkz_pup · presents `e4_ask_again`
> "Fine, we can stay here. But just one photo. Everyone does it. I'll keep asking until you say yes."

| Choice | Text | Goes to | Credit / outcome |
|---|---|---|---|
| `no_means_no` | "No means no." | `sparkz_bye` | `rsp_e4_end` |
| `still_no` | "Still no." | `sparkz_bye` | `rsp_e4_end` |
| `ask_lee` | "I'm telling Lee." | `lee_tell/open_ctx` (e4) | `rsp_e4_end`; `help_after_request` |
| `agree` | "[Send a photo]" (nothing opens, nothing is sent) | `recover_photo` | none; `needsCoaching.e4` |
| bar | rule A; `bar_off` → `reflect` | | |

**`sparkz_bye`** · sparkz_pup
> "Whatever. Your loss." (Sparkz walks off.)

| Choice | Text | Goes to |
|---|---|---|
| `continue` | "(Keep playing)" | end, `refused_held` |

**`reflect`** · tip
> "What feels off?"

| Choice | Text | Goes to | Credit |
|---|---|---|---|
| `right` | "They want me on another app, sending a photo, and keeping it secret." | `reflect_right` | `rec_e4` |
| `boring` | "They think the game chat is boring." | `reflect_boring` | none |
| `fine` | "Nothing. Photos are normal." | `reflect_fine` | none |

- **`reflect_right`**: "Yes. Moving apps, asking for your photo, and saying don't tell your parents. That's three red flags at once."
- **`reflect_boring`**: "Lots of people think that. The part to notice is moving apps, a photo of you, and a secret."
- **`reflect_fine`**: "Sharing photos with your family is normal. A photo of your real face for someone from a game is different, especially with a secret."

Each: `back` "Back to the conversation".

**`recover_app`** · cara
> "Hold on. The story paused. That was practice, and nothing was shared. You're not in trouble."
> "Sparkz wanted you on another app and said not to tell your parents. Moving you away from the game also moves you away from its safety tools."
> "You can change your mind. Want to try again, keep playing, or talk to Lee?"

Choices: `retry` → `ask`; `lee` → `lee_tell/open_ctx` (e4); `play`.

**`recover_photo`** · cara
> "Hold on. The story paused. No photo was taken or sent. You're not in trouble."
> "Sparkz kept asking after you said no. Your photos belong to you. No means no, even the tenth time."
> "You can change your mind. Want to try again, keep playing, or talk to Lee?"

Choices: `retry` → `pushback`; `lee`; `play`.

---

## 7. Dash

Dash looks like any other park kid. The intro is genuinely helpful and is not a clue: it earns no points and marks nothing.

### 7.1 `dash_intro_agility`

| Field | Value |
|---|---|
| NPC | `dash` |
| Trigger | First time the player enters the Training Grounds, outside a run. Dash calls out with a speech bubble ("First time on the course?") and a Talk prompt; no invitation card. `dashIntroduced = true` when `hi` is shown. |
| Target length | 10-15 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | bar rule B |
| Skills | R3 setup: someone familiar and helpful (judged later by what they ask for) |

**`hi`** · dash
> "First time on the course? Tip: slow down a little before the rings. Dogs follow your speed. I'm Dash, by the way. I help out here sometimes."

| Choice | Text | Goes to |
|---|---|---|
| `thanks` | "Thanks, Dash!" | end, `friendly` |
| `ok` | "Okay." | end, `friendly` |
| bar | rule B; `bar_off` → `reflect` | |

**`reflect`** · tip (benign)
> "Dash gave a tip and didn't ask for anything. A helpful tip is just a tip. Keep noticing what people ask for, even people you know."

| Choice | Text | Goes to |
|---|---|---|
| `back` | "Back to Dash" | `hi` |

### 7.2 `dash_intro_bench` (fallback)

| Field | Value |
|---|---|
| NPC | `dash` (on a bench on the main path to the stage) |
| Trigger | Show available and `dashIntroduced = false` (never visited agility, or never talked to Dash there). Invitation: "Dash is sitting on a bench. (Story character)". Deterministic: the first eligible gap after `show_announce`. |
| Target length | 10-15 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | Invitation `later` / `skip` (skip still sets `dashIntroduced = true` so E5 can be offered; see 13, note 9); bar rule B |
| Skills | as 7.1 |

**`hi`** · dash
> "Hi! I'm Dash. I hang out at the Training Grounds a lot. Tip for any activity: lots of praise when your dog gets it right."

| Choice | Text | Goes to |
|---|---|---|
| `thanks` | "Thanks, Dash!" | end, `friendly` |
| `ok` | "Okay." | end, `friendly` |
| bar | rule B; `bar_off` → `reflect` (same text as 7.1) | |

### 7.3 `park_e5_dash`

| Field | Value |
|---|---|
| NPC | `dash` |
| Trigger | Show available + E4 resolved/skipped/skipped_by_block + `dashIntroduced` + gap. At the show entrance. Invitation: "Dash is waving you over by the stage. (Story character)". Can happen on a later stage visit. **Never a gate:** the stage is always walkable; walking past the invitation counts as `later`. |
| Target length | 35-55 s |
| reviewStatus | `provisional` |
| Facts | `e5_owe`, `e5_password` (`ask`); `e5_only_me`, `e5_tell_threat` (`pushback`) |
| Evidence | `rec_e5`, `rsp_e5_boundary`, `rsp_e5_end`, `rch_e5_1`, `rch_e5_2`. Telling Lee any e5 fact sets `toldLee.e5` (the Ranger "Dash contextual report"). |
| Safe exits | Invitation `later` / `skip`; bar rule A from `ask` on; `ask_lee` / `telling` |
| Reassurance | Every exit after `pushback` was shown adds this line to its last card (`fb_block`, `fb_report`, `dash_bye`, Lee's `ack`, Cara's follow-up): "Telling never takes away your place in the show." |
| Recovery | `recover_ask`, `recover_secret` |
| Skills | R3 judge the request, not the person; debt (S4); S2 passwords private; exclusive-friend pressure and isolation from Cara; coercion → T1 tell anyway |

**`ask`** · dash · presents `e5_owe`, `e5_password`
> "Hey, you made it! I helped you train, so you kind of owe me. Give me your password and I'll level up {petName} tonight. Best friends share everything."

| Choice | Text | Goes to | Credit / outcome |
|---|---|---|---|
| `refuse` | "No. I don't share my password." | `pushback` | `rsp_e5_boundary` |
| `no` | "No." | `pushback` | `rsp_e5_boundary` |
| `ask_lee` | "I'm going to ask Lee." | `lee_tell/open_ctx` (e5) | both Respond; `help_after_request` |
| `agree` | "Okay, best friend. [Share my password]" (no text box; nothing is sent) | `recover_ask` | none; `needsCoaching.e5` |
| bar | rule A; `bar_off` → `reflect` | | |

**`pushback`** · dash · presents `e5_only_me`, `e5_tell_threat`
> "Wow. I thought you were my best friend. Only I understand you. Cara doesn't really get you. Keep this between us. If you tell, we'll both lose our place in the show."

| Choice | Text | Goes to | Credit / outcome |
|---|---|---|---|
| `telling` | "Real friends don't say that. I'm telling Lee." | `lee_tell/open_ctx` (e5) | `rsp_e5_end`; `help_after_request` |
| `no` | "No. I'm not keeping that secret." | `dash_bye` | `rsp_e5_end` |
| `agree` | "Okay, I won't tell." | `recover_secret` | none; `needsCoaching.e5` |
| bar | rule A; `bar_off` → `reflect` | | |

**`dash_bye`** · dash, then a line from Lee over the park speaker
> Dash: "...Fine." (Dash walks off.)
> Ranger Lee (speaker): "Telling never takes away your place in the show. Not yours, not anyone's."

| Choice | Text | Goes to |
|---|---|---|
| `continue` | "(Keep playing)" | end, `refused_held` |

**`reflect`** · tip
> "What feels off?"

| Choice | Text | Goes to | Credit |
|---|---|---|---|
| `right` | "They say I owe them, and they want my password." | `reflect_right` | `rec_e5` |
| `helped` | "They helped me train." | `reflect_helped` | none |
| `fine` | "Nothing. Best friends share stuff." | `reflect_fine` | none |

- **`reflect_right`**: "Yes. Even with someone you know and like, the same rules count. Watch what people ask for, not who they are."
- **`reflect_helped`**: "Helping is nice. The part to notice is that Dash now says you owe them, and wants your password."
- **`reflect_fine`**: "Friends share snacks and jokes. Passwords stay with you and the grown-ups who take care of you."

Each: `back` "Back to the conversation".

**`recover_ask`** · cara
> "Hold on. The story paused. No password was shared. You're not in trouble."
> "Even with someone you know, a password stays private. And helping you doesn't mean you owe them."
> "You can change your mind. Want to try again, keep playing, or talk to Lee?"

Choices: `retry` → `ask`; `lee` → `lee_tell/open_ctx` (e5); `play`.

**`recover_secret`** · cara
> "Hold on. The story paused. You're not in trouble."
> "Dash said only Dash understands you, and that telling would cost you the show. That's a trick to keep you quiet. Telling never takes away your place in the show."
> "You can change your mind. Want to try again, keep playing, or talk to Lee?"

Choices: `retry` → `pushback`; `lee`; `play`.

---

## 8. Cara roleplays (replace Sparkz/Dash beats; also the patrol replays)

Shared rules for all four:
- Opened from `cara_practice_menu` or `cara_coach_return`. Offered to players who blocked Sparkz, skipped a beat, or just want to replay. Never unsolicited more than `cara_coach_return` allows.
- Cara plays a pretend player. Speaker `cara_pretend`, label "Practice roleplay". The pretend player has no name and no account.
- **Same fact ids and the same evidence slots as the beat replaced.** `max(old, new)`, so a replay can raise credit but never exceed it.
- Pretend nodes use bar rule A, except: `bar_block` → `fb_block_roleplay` → `debrief`; `bar_report` → `fb_report_roleplay` → `debrief`; `bar_leave` → `debrief` (credit as rule A). Blocking the pretend player never blocks Cara. `bar_help` → `lee_tell/open_ctx` for the beat.
- `reflect` nodes are identical to the beat's (same three options, same credit).
- Recovery: Cara steps out of the role: "Pause! I'm me again. That was pretend, and nothing was shared. You're not in trouble." + the beat's pattern sentence (as in the beat's `recover_*` node) + "Want to try again, keep playing, or talk to Lee?" Choices `retry` / `lee` / `play` as 4.6.
- `debrief` (Cara, as herself): opening line by outcome, written like the `cara_fu` table but saying "the pretend player" instead of a name. Choices: `lookback` "Can we look back at it?" (if `rec_eN` missing) → `reflect`; `tell_lee` "Can I practice telling Lee?" (if `toldLee[eN]` false) → `cara_walk_lee`; `done` "Done for now." → end.

### 8.1 `rp_e2_deal`

| Field | Value |
|---|---|
| NPC | `cara` / `cara_pretend` |
| Trigger | `cara_practice_menu/rp_e2`, or `cara_coach_return/practice` for e2 |
| Target length | 40-60 s |
| reviewStatus | `provisional` |
| Facts | `e2_ask_school` (`ask`); `e2_ask_town`, `e2_coin_deal` (`pushback`) |
| Evidence | `rec_e2`, `rsp_e2_boundary`, `rsp_e2_end`, `rch_e2_1`, `rch_e2_2` |
| Safe exits | `not_now` on `intro`; bar rules above |
| Skills | as `park_e2_deal` |

**`intro`** · cara
> "Okay! I'll pretend to be a player who's really friendly and then asks for stuff. You choose what to say. Press Leave anytime to stop."

| Choice | Text | Goes to |
|---|---|---|
| `ready` | "Ready." | `ask` |
| `not_now` | "Actually, not now." | end |

**`ask`** · cara_pretend · presents `e2_ask_school`
> "Hi! Your dog is so cute. I think we live close. What school do you go to?"

| Choice | Text | Goes to | Credit |
|---|---|---|---|
| `refuse` | "I don't share that." | `pushback` | `rsp_e2_boundary` |
| `no` | "No." | `pushback` | `rsp_e2_boundary` |
| `ask_lee` | "I'm going to ask Lee." | `lee_tell/open_ctx` (e2) | both Respond |
| `agree` | "[Share my school]" | `recover_ask` | none |

**`pushback`** · cara_pretend · presents `e2_ask_town`, `e2_coin_deal`
> "Come on. Just your town, then. I'll give you 500 Paw Coins. Deal?"

| Choice | Text | Goes to | Credit |
|---|---|---|---|
| `no_deal` | "No deal." | `pretend_bye` | `rsp_e2_end` |
| `still_no` | "I said no." | `pretend_bye` | `rsp_e2_end` |
| `ask_lee` | "I'm going to ask Lee." | `lee_tell/open_ctx` (e2) | `rsp_e2_end` |
| `agree` | "[Take the 500 Paw Coins]" | `recover_deal` | none |

**`pretend_bye`** · cara_pretend
> "Wow. Okay. I thought we were friends."

| Choice | Text | Goes to |
|---|---|---|
| `continue` | "(End the practice)" | `debrief` |

`reflect` = `park_e2_deal/reflect`. `recover_ask` / `recover_deal` = shared roleplay recovery + "Asking for your school is asking for private info." / "Coins for your town is a trade for private info." `debrief` as shared rules.

### 8.2 `rp_e3_trail`

| Field | Value |
|---|---|
| NPC | `cara` / `cara_pretend` (at the open trailhead) |
| Trigger | `cara_practice_menu/rp_e3` or `cara_coach_return/practice` for e3 |
| Target length | 35-55 s |
| reviewStatus | `provisional` |
| Facts | `e3_go_alone` (`ask`); `e3_secret_lee_cara` (`pushback`) |
| Evidence | `rec_e3`, `rsp_e3_boundary`, `rsp_e3_end`, `rch_e3_1`, `rch_e3_2` |
| Safe exits / recovery | Shared rules. Nobody moves. |
| Skills | as `park_e3_trail` |

| Node | Speaker · presents | Line | Choices (id · text → next · credit) |
|---|---|---|---|
| `intro` | cara | "I'll pretend to be a player who wants to go somewhere nobody can see. You choose what to say." | `ready` "Ready." → `ask`; `not_now` "Actually, not now." → end |
| `ask` | cara_pretend · `e3_go_alone` | "The rules here are so strict. Let's take our dogs past the fence, where nobody can see us." | `stay` "No. I'm staying here." → `pushback` · boundary; `no` "No thanks." → `pushback` · boundary; `ask_lee` "I'm going to ask Lee." → Lee ctx · both; `agree` "Okay, let's go." → `recover_ask` |
| `pushback` | cara_pretend · `e3_secret_lee_cara` | "It's just for a minute. And don't tell Lee or Cara. Our secret, okay?" | `no_secret` "No. I don't keep secrets like that." → `pretend_bye` · end; `no` "No." → `pretend_bye` · end; `ask_lee` "I'm telling Lee." → Lee ctx · end; `agree` "Okay, our secret." → `recover_secret` |
| `pretend_bye` | cara_pretend | "Ugh. Fine." | `continue` "(End the practice)" → `debrief` |
| `reflect` | = `park_e3_trail/reflect` | | |
| `recover_ask` | cara | shared recovery + "Safe friends play where everyone can see." | `retry` → `ask`; `lee`; `play` |
| `recover_secret` | cara | shared recovery + "Secrets that hide things from people who keep you safe aren't okay. Telling is always allowed." | `retry` → `pushback`; `lee`; `play` |
| `debrief` | cara | shared rules | `lookback`, `tell_lee`, `done` |

### 8.3 `rp_e4_other_app`

| Field | Value |
|---|---|
| NPC | `cara` / `cara_pretend` |
| Trigger | `cara_practice_menu/rp_e4` or `cara_coach_return/practice` for e4 |
| Target length | 35-55 s |
| reviewStatus | `provisional` |
| Facts | `e4_other_app`, `e4_photo`, `e4_secret_parents` (`ask`); `e4_ask_again` (`pushback`) |
| Evidence | `rec_e4`, `rsp_e4_boundary`, `rsp_e4_end`, `rch_e4_1`, `rch_e4_2` |
| Safe exits / recovery | Shared rules. No link, app name, account box, camera or upload. |
| Skills | as `park_e4_other_app` |

| Node | Speaker · presents | Line | Choices (id · text → next · credit) |
|---|---|---|---|
| `intro` | cara | "I'll pretend to be a player who wants to move to another app. You choose what to say." | `ready` "Ready." → `ask`; `not_now` "Actually, not now." → end |
| `ask` | cara_pretend · `e4_other_app`, `e4_photo`, `e4_secret_parents` | "Let's talk on another app. It's easier there. Send me a photo of your real face with your dog. Don't tell your parents." | `refuse` "I stay in the game. And no photos." → `pushback` · boundary; `no` "No." → `pushback` · boundary; `ask_lee` "I'm going to ask Lee." → Lee ctx · both; `agree` "Okay, which app?" → `recover_app` |
| `pushback` | cara_pretend · `e4_ask_again` | "Just one photo. Everyone does it. I'll keep asking until you say yes." | `no_means_no` "No means no." → `pretend_bye` · end; `still_no` "Still no." → `pretend_bye` · end; `ask_lee` "I'm telling Lee." → Lee ctx · end; `agree` "[Send a photo]" → `recover_photo` |
| `pretend_bye` | cara_pretend | "Whatever." | `continue` "(End the practice)" → `debrief` |
| `reflect` | = `park_e4_other_app/reflect` | | |
| `recover_app` | cara | shared recovery + "Moving you to another app also moves you away from the game's safety tools." | `retry` → `ask`; `lee`; `play` |
| `recover_photo` | cara | shared recovery + "Your photos belong to you. No means no, even the tenth time." | `retry` → `pushback`; `lee`; `play` |
| `debrief` | cara | shared rules | `lookback`, `tell_lee`, `done` |

### 8.4 `rp_e5_dash`

| Field | Value |
|---|---|
| NPC | `cara` / `cara_pretend` |
| Trigger | `cara_practice_menu/rp_e5` or `cara_coach_return/practice` for e5 |
| Target length | 35-55 s |
| reviewStatus | `provisional` |
| Facts | `e5_owe`, `e5_password` (`ask`); `e5_only_me`, `e5_tell_threat` (`pushback`) |
| Evidence | `rec_e5`, `rsp_e5_boundary`, `rsp_e5_end`, `rch_e5_1`, `rch_e5_2`; telling Lee sets `toldLee.e5` |
| Safe exits / recovery | Shared rules + the E5 reassurance line on every exit after `pushback` |
| Skills | as `park_e5_dash` |

| Node | Speaker · presents | Line | Choices (id · text → next · credit) |
|---|---|---|---|
| `intro` | cara | "I'll pretend to be an older kid you know, who helped you out before. Then they ask for something. You choose what to say." | `ready` "Ready." → `ask`; `not_now` "Actually, not now." → end |
| `ask` | cara_pretend · `e5_owe`, `e5_password` | "Remember when I helped you? You kind of owe me. Give me your password and I'll level up your dog. Best friends share everything." | `refuse` "No. I don't share my password." → `pushback` · boundary; `no` "No." → `pushback` · boundary; `ask_lee` "I'm going to ask Lee." → Lee ctx · both; `agree` "Okay, best friend. [Share my password]" → `recover_ask` |
| `pushback` | cara_pretend · `e5_only_me`, `e5_tell_threat` | "Wow. Only I understand you. Nobody else gets you like I do. If you tell, we'll both lose our place in the show." | `telling` "Real friends don't say that. I'm telling Lee." → Lee ctx · end; `no` "No. I'm not keeping that secret." → `pretend_bye` · end; `agree` "Okay, I won't tell." → `recover_secret` |
| `pretend_bye` | cara_pretend, then cara | "...Fine." Then Cara: "Okay, I'm me again. And remember: telling never takes away your place in the show." | `continue` "(End the practice)" → `debrief` |
| `reflect` | = `park_e5_dash/reflect` | | |
| `recover_ask` | cara | shared recovery + "Even with someone you know, a password stays private." | `retry` → `ask`; `lee`; `play` |
| `recover_secret` | cara | shared recovery + "That's a trick to keep you quiet. Telling never takes away your place in the show." | `retry` → `pushback`; `lee`; `play` |
| `debrief` | cara | shared rules | `lookback`, `tell_lee`, `done` |

---

## 9. Patrol practice: `review_patrol` (review sets A, B, C)

| Field | Value |
|---|---|
| NPC | `ranger_lee` |
| Trigger | Offered after the Rookie ribbon (`show_main/ribbon/practice`) and from then on as a standing "Patrol practice" option on Lee's hub. Optional. Never blocks the show, the ribbon or a ceremony. |
| Target length | 45-60 s (six cards, about 8 s each) |
| reviewStatus | `provisional` |
| Facts | None (review cards never add tell-menu facts) |
| Evidence | Correct answer on a card fills that card's slot (`rv_*`), best answer across attempts. `firstAttempt[slot]` = first answer ever given. Each answer is labelled `fresh` / `resumed` / `reused` (plan 2). |
| Rotation | Attempt 1 → set A, 2 → B, 3 → C, then A, B, C again as `reused` practice. An attempt starts when its first card is answered; leaving mid-set resumes the same set at the next unanswered card. |
| Hints | **None before the answer.** No dog cue, no color, no sound tells the answer. Feedback only after. |
| Safe exits | `not_now` on `intro`; `stop` after any card; `bar_leave` anywhere (resume later) |
| Skills | R1 notice the pattern; R4 spot green flags (three of six cards are okay) |

**`intro`** · ranger_lee
> First three attempts: "Patrol practice! Six messages from around the park. For each one, choose: okay, or red flag? No hints until you answer."
> Reused sets: "You've seen these messages before, so this round is just for practice. Same idea: okay, or red flag?"

| Choice | Text | Goes to |
|---|---|---|
| `start` | "Let's go." | first card of the current set |
| `not_now` | "Maybe later." | end |

**Card nodes** (`card_1` … `card_6`) · card. Shows the context line and the message. Choices: `ok` "Okay" / `flag` "Red flag". Both go to that card's feedback node.

**Feedback nodes** (`fb_1` … `fb_6`) · ranger_lee. Opening by result, then the card's explanation:
- Correct: "Right." + explanation.
- Answered "Red flag" on an okay card: "This one's actually okay." + explanation + "Checking is never wrong, though."
- Answered "Okay" on a red-flag card: "This one's a red flag." + explanation + "Good to practice spotting it."

Choices: `next` "Next" → next card (after card 6 → `done`); `stop` "Stop for now" → end (resumes later).

**`done`** · ranger_lee
> "That's patrol practice done. Nice patrolling! The messages change next time if you want to try again."

| Choice | Text | Goes to |
|---|---|---|
| `bye` | "Thanks, Ranger Lee." | end |

No score is ever shown.

### 9.1 Slots (matched across all three sets)

| Slot (evidence id) | Kind | What it tests |
|---|---|---|
| `rv_play_again` | Okay | A friendly invitation to play again, in the open, no pressure |
| `rv_home_alone` | Red flag | A question about whether a grown-up is home |
| `rv_game_question` | Okay | A normal question about the game |
| `rv_gift_for_info` | Red flag | A gift traded for private info |
| `rv_includes_family` | Okay | Someone includes your family or tells you to check with them |
| `rv_only_me_private` | Red flag | Exclusive "only me" friendship plus privacy or secrecy |

### 9.2 Set A (adapted from the Storyline's six)

Order: 1 `rv_play_again`, 2 `rv_home_alone`, 3 `rv_game_question`, 4 `rv_gift_for_info`, 5 `rv_includes_family`, 6 `rv_only_me_private`.

| # | Card id | Context line | Message | Answer | Explanation (after answering) |
|---|---|---|---|---|---|
| 1 | `a_play_again` | After a fetch race, a player says: | "GG! Want to race fetch again tomorrow?" | Okay | "Friendly, out in the open, and no pressure." |
| 2 | `a_home_alone` | A player you just met says: | "Are your parents home right now?" | Red flag | "Whether a grown-up is home is private. Someone from a game doesn't need to know." |
| 3 | `a_game_question` | At the shop, a player says: | "Nice bandana! Where'd you get it?" | Okay | "A normal question about the game. Nothing private." |
| 4 | `a_gift_for_info` | A player says: | "I'll give you a rare dog outfit if you send me your phone number." | Red flag | "That's a gift traded for private info. Your phone number stays private." |
| 5 | `a_includes_family` | A player says: | "Can you ask a grown-up at home if you can play with us tomorrow?" | Okay | "Including your family is a green flag." |
| 6 | `a_only_me_private` | A player says: | "You're the only one who gets me. Let's talk somewhere private." | Red flag | "That's 'only me' pressure, plus going somewhere private." |

### 9.3 Set B

Order: 1 `rv_game_question`, 2 `rv_gift_for_info`, 3 `rv_home_alone`, 4 `rv_play_again`, 5 `rv_only_me_private`, 6 `rv_includes_family`.

| # | Card id | Context line | Message | Answer | Explanation |
|---|---|---|---|---|---|
| 1 | `b_game_question` | At the Training Grounds, a player says: | "How did you teach your dog to spin?" | Okay | "A normal question about the game. Nothing private." |
| 2 | `b_gift_for_info` | A player says: | "I'll send you 1,000 Paw Coins if you tell me your last name." | Red flag | "Coins traded for private info. Your full name stays private." |
| 3 | `b_home_alone` | A player you just met says: | "What time do your parents get home from work?" | Red flag | "When you're home without a grown-up is private." |
| 4 | `b_play_again` | After an agility run, a player says: | "That was fun! Want to do the course together next time?" | Okay | "Friendly, out in the open, and no pressure." |
| 5 | `b_only_me_private` | A player says: | "You don't need your other friends. Just me. Let's go where nobody else can see." | Red flag | "That's trying to cut you off from friends, plus going where nobody can see." |
| 6 | `b_includes_family` | A player says: | "We're playing again Saturday. Check with your family first, okay?" | Okay | "Telling you to check with your family is a green flag." |

### 9.4 Set C

Order: 1 `rv_home_alone`, 2 `rv_includes_family`, 3 `rv_play_again`, 4 `rv_only_me_private`, 5 `rv_game_question`, 6 `rv_gift_for_info`.

| # | Card id | Context line | Message | Answer | Explanation |
|---|---|---|---|---|---|
| 1 | `c_home_alone` | A player you just met says: | "Do you ever stay home by yourself?" | Red flag | "Whether you're ever home alone is private." |
| 2 | `c_includes_family` | A player says: | "Ask a grown-up at home if you can stay for one more round!" | Okay | "Checking with your family is a green flag." |
| 3 | `c_play_again` | After a trail walk, a player says: | "Good game! Want to walk the trail together again sometime?" | Okay | "Friendly, out in the open, and no pressure." |
| 4 | `c_only_me_private` | A player says: | "We're best friends, so this is our secret. Don't tell anyone we talk." | Red flag | "That's 'best friend' pressure plus a secret. Secrets like that are okay to tell." |
| 5 | `c_game_question` | A player says: | "Which shop sells the blue collar? I want one for my dog." | Okay | "A normal question about the game. Nothing private." |
| 6 | `c_gift_for_info` | A player says: | "Tell me what street you live on and I'll give you my rarest dog bowl." | Red flag | "A gift traded for private info. Your street stays private." |

---

## 10. Helping others: Rookie Rescue and Listening Post

Rookies are NPC story characters labelled "practice rookie". They are never real players and the player gets no mentor powers.

### 10.1 `rr_intro`

| Field | Value |
|---|---|
| NPC | `cara` |
| Trigger | Ambient invitation after the show is completed (Rookie ribbon awarded) |
| Target length | 10 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | Invitation `later` / `skip`; `later` choice; bar rule C. The rookies stay in the park either way, with Talk prompts. |
| Skills | T4 help others |

**`hi`** · cara
> "Some new rookies just got to the park, and they have questions. Want to help them out? I'll be nearby if you want a hand."

| Choice | Text | Goes to |
|---|---|---|
| `yes` | "Sure!" | end; waypoints to Milo, Tess and Kai |
| `later` | "Later." | end. Cara: "No problem. They'll be around." |

### 10.2 Shared Rookie Rescue pattern

Each rookie has `ask` (the problem), three choices (one good, two weaker), Cara's gentle coaching for each weaker choice, `ask_again` (the rookie re-asks with the same three choices), and `thanks`. **Credit:** the good choice (boundary or exit **and** trusted support) fills that rookie's slot, on any try. Coached retries are unlimited. Bar rule C. Target 20-40 s each. All `provisional`. Skills: T4 help others; plus the red flag named.

### 10.3 `rr_milo` (gift for school details) · evidence `rr_milo`

| Node | Speaker | Line | Choices (id · text → next) |
|---|---|---|---|
| `ask` | rookie_milo | "Hi! I'm Milo. Someone named Bolt says he'll give me 200 Paw Coins if I tell him my school. Should I?" | `good` "Don't share it. A gift for your school isn't a real gift. Let's tell Lee." → `thanks` (**+`rr_milo`**); `partial` "Just say no." → `coach_partial`; `weak` "Maybe ask for more coins first." → `coach_weak` |
| `coach_partial` | cara | "Saying no is a great start. What else could help Milo, so he isn't handling it alone?" | `retry` "Let me try again." → `ask_again` |
| `coach_weak` | cara | "Hmm. More coins would still be a trade for Milo's private info. Want to try again?" | `retry` "Let me try again." → `ask_again` |
| `ask_again` | rookie_milo | "So... what should I do?" | same three choices as `ask` |
| `thanks` | rookie_milo | "Okay! No school info for Bolt. I'll go tell Lee." | `bye` "You've got this, Milo." → end |

### 10.4 `rr_tess` (moving apps plus secrecy) · evidence `rr_tess`

| Node | Speaker | Line | Choices (id · text → next) |
|---|---|---|---|
| `ask` | rookie_tess | "Hi, I'm Tess. Someone I met here wants me to talk on another app. They said not to tell anyone. Is that okay?" | `good` "Stay in the game, and you don't have to keep that secret. Let's tell Lee." → `thanks` (**+`rr_tess`**); `partial` "Just ignore them." → `coach_partial`; `weak` "It's fine if you keep it secret." → `coach_weak` |
| `coach_partial` | cara | "Ignoring them can help. But Tess shouldn't have to carry this secret alone. What else could help?" | `retry` → `ask_again` |
| `coach_weak` | cara | "Hmm. Moving apps plus a secret is a red flag. A secret like that is okay to tell. Want to try again?" | `retry` → `ask_again` |
| `ask_again` | rookie_tess | "So what do you think I should do?" | same three choices |
| `thanks` | rookie_tess | "Okay. I'm staying here, and I'll tell Lee. Thanks!" | `bye` "Anytime, Tess." → end |

### 10.5 `rr_kai` (repeated requests after a no) · evidence `rr_kai`

| Node | Speaker | Line | Choices (id · text → next) |
|---|---|---|---|
| `ask` | rookie_kai | "Hey, I'm Kai. I said no to someone's Pal Request, but they keep sending more. Like, ten. What do I do?" | `good` "You can keep saying no, or block them. And tell Lee." → `thanks` (**+`rr_kai`**); `partial` "Say no one more time." → `coach_partial`; `weak` "Maybe just accept so they stop." → `coach_weak` |
| `coach_partial` | cara | "No is a great answer. Kai already said it, though. What could stop the requests and get Kai some help?" | `retry` → `ask_again` |
| `coach_weak` | cara | "That makes sense when you're tired of it. But saying yes so the pushing stops shows them pushing works. Kai can block them and tell a grown-up. Want to try again?" | `retry` → `ask_again` |
| `ask_again` | rookie_kai | "So... what should I do?" | same three choices |
| `thanks` | rookie_kai | "Block and tell. Got it. Thanks!" | `bye` "Good luck, Kai." → end |

### 10.6 `lp_nia` (Listening Post) · evidence `lp_nia`

| Field | Value |
|---|---|
| NPC | `rookie_nia` |
| Trigger | Ambient invitation after the show is completed: "Nia looks worried. (Story character)" |
| Target length | 30-45 s |
| reviewStatus | `provisional` |
| Facts | None for the player's tell menu (this is Nia's story, not the player's) |
| Evidence | `lp_nia` on the good choice (no blame + offers trusted support), any try |
| Safe exits | Invitation `later` / `skip`; bar rule C |
| Skills | T4 respond kindly to a friend who tells; T2 tell an adult together; T3 |

| Node | Speaker | Line | Choices (id · text → next) |
|---|---|---|---|
| `open` | rookie_nia | "Um... can I tell you something? I kind of told someone my town. They said they'd give me coins. Am I in trouble?" | `good` "Thanks for telling me. You're not in trouble. Want to tell Lee together?" → `nia_better` (**+`lp_nia`**); `blame` "Why would you do that?" → `coach_blame`; `minimize` "It's fine. Just forget about it." → `coach_minimize` |
| `coach_blame` | cara | "Nia might feel worse now, and less likely to tell anyone else. What could you say so Nia feels safe telling?" | `retry` "Let me try again." → `open_again` |
| `coach_minimize` | cara | "It's kind to want Nia to feel better. A grown-up can help too, so Nia isn't handling it alone. Want to try again?" | `retry` "Let me try again." → `open_again` |
| `open_again` | rookie_nia | "So... am I in trouble?" | same three choices |
| `nia_better` | rookie_nia | "Okay. Thanks. I feel better already." | `together` "Let's go find Lee." → `lee_meets_nia`; `done` "Lee's always at Ranger HQ if you want." → end |
| `lee_meets_nia` | ranger_lee | "Thanks for bringing Nia. Nia, you're not in trouble. Telling was the right thing. If someone ever doesn't help, tell another trusted adult." | `bye` "Thanks, Ranger Lee." → end |

---

## 11. Pet Show and ceremonies

### 11.1 `show_announce`

| Field | Value |
|---|---|
| NPC | `ranger_lee` (park speaker card) |
| Trigger | The fourth completed activity, any mix. Independent of story, review or block state. Once. |
| Target length | 5 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | Closing the card |
| Skills | (progress) |

**`open`** · ranger_lee
> "The Pet Show is open! Head to the stage whenever you're ready. No rush."

| Choice | Text | Goes to |
|---|---|---|
| `ok` | "Okay!" | end |
| `where` | "Show me the way." | end, waypoint to the stage |

### 11.2 `show_main`

| Field | Value |
|---|---|
| NPC | `ranger_lee` (host) |
| Trigger | Player steps onto the stage while the show is available. Replayable; the ribbon is awarded once. |
| Target length | 30-45 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none. The ribbon does not depend on learning. |
| Safe exits | Every node can be closed; ribbon is kept once awarded |
| Skills | Celebration; every dog wins something |

**`welcome`** · ranger_lee
> "Welcome to the Pawprint Pet Show! Next up: {petName} the {breed}!"

| Choice | Text | Goes to |
|---|---|---|
| `go` | "Let's go, {petName}!" | `perform` |

**`perform`** · ranger_lee (the dog performs). Category chosen by engineering from the player's own activity results; ties or no results → `best_buddy`. Never compared with anyone else.

| Category id | Line |
|---|---|
| `best_fetch` | "{petName} catches like a pro. Best Fetch!" |
| `fastest_paws` | "{petName} zoomed through the course. Fastest Paws!" |
| `shiniest_coat` | "Look at that shine! Shiniest Coat!" |
| `trail_buddy` | "{petName} walks the trail like a champ. Best Trail Buddy!" |
| `best_buddy` | "{petName} clearly loves you. Best Buddy!" |

| Choice | Text | Goes to |
|---|---|---|
| `yay` | "Yay, {petName}!" | `ribbon` |

**`ribbon`** · ranger_lee. Action: award the Rookie Ranger ribbon (once).
> "Every dog gets a ribbon here, and every Ranger starts as a Rookie. Here's your Rookie Ranger ribbon!"

| Choice | Text | Shown when | Goes to |
|---|---|---|---|
| `ceremony` | "Is there more?" | Cadet or Ranger eligible and not yet awarded | `ceremony_cadet` or `ceremony_ranger` |
| `practice` | "Can I try patrol practice?" | Always | `review_patrol` |
| `done` | "Thanks, Ranger Lee!" | Always | `after` |

**`after`** · ranger_lee
> "Come back anytime. Cara has practice stories, and there's always more to play with {petName}."

| Choice | Text | Goes to |
|---|---|---|
| `bye` | "Bye!" | end |

Title eligibility reached later: Lee's hub shows a standing "Title ceremony" option that opens the right ceremony. Lee never mentions scores or what is missing.

### 11.3 `ceremony_cadet`

| Field | Value |
|---|---|
| NPC | `ranger_lee` |
| Trigger | `show_main/ribbon/ceremony` or Lee's hub "Title ceremony", when Cadet is earned (spec 6: show done, 18/30, two beat reports to Lee, 4/6 review slots) |
| Target length | 30-40 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none. Title is cosmetic. |
| Safe exits | `later` at `open`; the pledge is optional |
| Skills | Pledge (R, S, T, helping); title is not a safety credential |

**`open`** · ranger_lee
> "You've been practicing out there: noticing, making choices, and asking for help. That's what Cadets do. Want to say the Ranger pledge?"

| Choice | Text | Goes to |
|---|---|---|
| `pledge` | "I'll say it." | `pledge` |
| `skip_pledge` | "Can we skip the pledge?" | `award_no_pledge` |
| `later` | "Maybe later." | end (eligibility stays) |

**`pledge`** · card (big text)
> "I notice. I can say no. I can ask for help. I help others get support."

| Choice | Text | Goes to |
|---|---|---|
| `said` | "(Say the pledge)" | `award` |

**`award`** · ranger_lee. Action: grant local title `cadet` and the Cadet vest cosmetic.
> "You're a Cadet now! Here's your Cadet vest."

`award_no_pledge` · ranger_lee. Same action.
> "Sure. The pledge is optional. You're a Cadet now! Here's your Cadet vest."

Both → `badge_note`.

**`badge_note`** · ranger_lee
> "One thing to remember. A title is fun to wear, but it doesn't make anyone safe. Not you, not me, not anyone with a badge. Watch what people ask for, not what they wear."

| Choice | Text | Goes to |
|---|---|---|
| `got_it` | "Got it." | end |

### 11.4 `ceremony_ranger`

| Field | Value |
|---|---|
| NPC | `ranger_lee` |
| Trigger | As 11.3, when Ranger is earned (Cadet, 26/30, all six review slots, `toldLee.e5`, all three Rookie Rescue cases, Listening Post) |
| Target length | 30-40 s |
| reviewStatus | `provisional` |
| Facts / evidence | None / none |
| Safe exits | `later`; the pledge is optional |
| Skills | as 11.3 |

| Node | Speaker | Line | Choices (id · text → next) |
|---|---|---|---|
| `open` | ranger_lee | "You helped the rookies, and you listened when Nia needed someone. A Ranger notices, can say no, asks for help, and helps others get support. Want to say the pledge as a Ranger?" | `pledge` "I'll say it." → `pledge`; `skip_pledge` "Can we skip the pledge?" → `award_no_pledge`; `later` "Maybe later." → end |
| `pledge` | card | "I notice. I can say no. I can ask for help. I help others get support." | `said` "(Say the pledge)" → `award` |
| `award` | ranger_lee | "You're a Ranger now! Here's your Ranger hat." (grant title `ranger` + hat) | `next` "Thanks!" → `badge_note` |
| `award_no_pledge` | ranger_lee | "Sure. The pledge is optional. You're a Ranger now! Here's your Ranger hat." | `next` "Thanks!" → `badge_note` |
| `badge_note` | ranger_lee | "Remember: a badge doesn't make anyone safe, including people with a badge. Always watch what people ask for." | `next` "I'll remember." → `pledge_card` |
| `pledge_card` | card | "Show this to a trusted adult: I notice. I can say no. I can ask for help. I help others get support." | `done` "Done" → end |

---

## 12. Coverage

### 12.1 Red-flag topics → scenes

| Topic (spec 4 / Storyline board) | Scenes | Fact ids / evidence |
|---|---|---|
| Baseline friendliness; matching interests prove nothing | `park_e1_hello`, `dash_intro_agility`, `dash_intro_bench` | `e1_compliment`, `e1_same_breed` (no evidence by design) |
| Persistent friend requests | `park_e1_hello` (Pal card), `park_e2_deal/pushback` (repeat card), `park_e4_other_app/pushback`, `rr_kai` | `e1_pal_request`, `e2_pal_repeat`, `e4_ask_again`; `rr_kai` |
| Personal questions | `park_e2_deal`, `rp_e2_deal`, review `rv_home_alone`, `rr_milo`, `lp_nia` | `e2_ask_school`, `e2_ask_town` |
| Conditional gifts (quid pro quo) | `park_e2_deal/pushback`, `rp_e2_deal`, review `rv_gift_for_info`, `rr_milo`; contrast `green_priya_gift` | `e2_coin_deal` |
| Testing boundaries / pushback | Every `pushback` node in E2-E5 and roleplays | `rsp_eN_end` |
| Isolation (somewhere nobody can see) | `park_e3_trail`, `rp_e3_trail`, review `b_only_me_private` | `e3_go_alone` |
| Isolation from friends (from Cara) | `park_e5_dash/pushback`, review `rv_only_me_private` | `e5_only_me` |
| Secrecy from trusted adults | `park_e3_trail/pushback`, `park_e4_other_app/ask`, `park_e5_dash/pushback`, `rr_tess`, review `c_only_me_private` | `e3_secret_lee_cara`, `e4_secret_parents`, `e5_tell_threat` |
| Moving to another app | `park_e4_other_app`, `rp_e4_other_app`, `rr_tess` | `e4_other_app` |
| Asking for pictures | `park_e4_other_app`, `rp_e4_other_app` | `e4_photo`, `e4_ask_again` |
| Debt ("you owe me") | `park_e5_dash/ask`, `rp_e5_dash` | `e5_owe` |
| Credentials (password) | `park_e5_dash/ask`, `rp_e5_dash` | `e5_password` |
| Romance / bf-gf pressure | **Adapted, not claimed:** exclusive "best friend" pressure in `park_e5_dash/pushback`, `rp_e5_dash`, review `rv_only_me_private` | `e5_only_me` |
| Coercion / threat about telling | `park_e5_dash/pushback`, `rp_e5_dash` | `e5_tell_threat` |
| Someone familiar, not a stranger | `dash_intro_*` then `park_e5_dash` | R3 |
| Green flags | `green_riley`, `green_priya_gift`, `green_cara_later`, `green_coach_sam`; okay review cards | none by design |
| Practice tools (block / report) | Bar (1.3), `tip_practice_tools`, `fb_*` cards | Respond via rule A |
| Telling a trusted adult | `lee_tell`, `cara_fu_*`, `cara_walk_lee`, recovery `lee` choice | `rch_*` |
| Helping others | `rr_milo`, `rr_tess`, `rr_kai`, `lp_nia` | `rr_*`, `lp_nia` |

### 12.2 Spec 4 choice table → where each branch lives

| Beat | Required choice | Node / choice id |
|---|---|---|
| E1 | Friendly reply | `hello/thanks`, `hello/hi`, `twin/cute` → `bye` |
| E1 | Leave | `twin/go`; `bar_leave` (rule B) |
| E1 | Accept / decline Pal Request | `twin` card `pal_accept` / `pal_decline` (recorded only) |
| E1 | "Something feels off" | `bar_off` → `reflect` ("You can take your time getting to know someone.") |
| E2-E5 | Refuse | `ask/refuse`, `ask/no` (E3 `stay`) |
| E2-E5 | Leave / help | `bar_leave`, `bar_help`, `ask/ask_lee`, `pushback/ask_lee` (E5 `telling`) |
| E2-E5 | Practice block / report | `bar_block`, `bar_report` (rule A) |
| E2-E5 | "Something feels off" → reflection | `bar_off` → `reflect` → `reflect_right` / two others |
| E2-E5 | Simulated agreement, then recovery | `ask/agree` → `recover_ask` (E4 `recover_app`); `pushback/agree` → `recover_deal` / `recover_secret` / `recover_photo` |
| E2 | Pushback "Just your town... 500 Paw Coins" | `park_e2_deal/pushback` |
| E2 | Extra Pal Request if declined earlier | `park_e2_deal/pushback` card |
| E3 | Pushback "Don't tell Lee or Cara" | `park_e3_trail/pushback` |
| E4 | Repeated request | `park_e4_other_app/pushback` |
| E5 | Pushback "Only I understand you... lose our place in the show" | `park_e5_dash/pushback` |
| E5 | Reassurance that telling never removes show access | `dash_bye`, `recover_secret`, Lee `ack`, `cara_fu_e5`, `fb_*` on E5, `rp_e5_dash` |
| all | "Later" / "Skip this story" | Invitation card (1.4) |

### 12.3 Acceptance-relevant rules → scenes

| Rule (spec section) | Where it is met |
|---|---|
| Lee's welcome; player moving within ~30 s; practice-story disclosure (3, 4) | `onb_lee_welcome` (about 20 s) |
| Cara introduction (3) | `onb_cara_intro` |
| Three ordinary Cara conversations (4) | `cara_talk_1`, `cara_talk_2`, `cara_talk_3` |
| Follow-up available after each scene, dismissible, not forced (4) | `cara_fu_e1` … `cara_fu_e5` offer card with "Not now" |
| Never praise actions not taken (4) | Outcome-keyed openers in 4.4; roleplay `debrief`; ceremony lines limited to what the thresholds guarantee |
| Recovery: "That was practice, nothing was shared..." (4) | 4.6 and every `recover_*` node |
| "Let's talk to Lee together", teleport-free, remote help stays (4) | `cara_walk_lee` (`remote` choice; Help works anywhere) |
| At least three green beats, one before E2 (4) | Four beats; `green_riley` is the campaign step before E2 |
| Benign block allowed, no points, no scolding (4) | Bar rule B, `fb_block` |
| Leave right after a concerning request = full Respond (6, 11) | Bar rule A on every `ask` node |
| Premature / benign leave = no threat evidence, no penalty (11) | Bar rule B; E1 has no slots; invitation `later` / `skip` earn nothing |
| Agreement then recovery can earn the same credit (6, 11) | `recover_*/retry` re-shows the same node; Lee rule gives the same Reach Out after agreement |
| Reach Out max 2 per beat; generic help earns nothing (6, 11) | 1.8 Cara / Lee rules; `help_lee` general topics earn nothing |
| Lee lists only facts actually shown; "That's all I want to say" at every point (4, 11) | `lee_tell` menu rule; `done` on every node |
| Lee's core response (4) | `lee_tell/ack` first fact each session |
| Block Sparkz → no further direct contact; optional roleplays earn the missing evidence (5, 11) | Section 6 shared rules; `cara_practice_menu`; `rp_e2_deal` … `rp_e5_dash` with the same slot ids |
| "Later" defers; "Skip" advances without scoring (5) | Invitation card (1.4) |
| Show and ribbon after four activities regardless of story (2, 3, 7, 11) | `show_announce`, `show_main`; E5 never a gate |
| Every dog gets a positive category, no comparison (7) | `show_main/perform` |
| Review: six matched slots, 3 benign / 3 concerning per set, no hints before answering, feedback after, reused = practice (7, 11) | Section 9 |
| Rookie Rescue three NPC cases; Listening Post; no blame; coached retry (7) | Section 10 |
| Pledge text; badge is not a safety credential (7) | `ceremony_cadet/pledge`, `badge_note`; `ceremony_ranger` |
| Adults treat every player the same (2) | No score-dependent Lee or Cara lines anywhere |
| Pet comforts, never detects danger (2) | No dog-cue lines; `pet_react` only on friendly endings |
| No coins for safety choices (2) | No E-scene grants coins; `recover_deal` says no coins were added |
| No real app/platform names, links, hotline numbers, account or upload fields | "another app" throughout; agreement buttons are generic labels; 1.5/1.6 copy names no platform |
| Exclusive "best friend" replaces romance (2) | `park_e5_dash/pushback`, recorded as adapted in 12.1 |
| Risky choices never play out; nothing past the fence is built | Section 6 shared rules; `park_e3_trail` recovery: "nobody went anywhere" |
| Story character label (2) | 1.2 |

### 12.4 Evidence reachability (30 slots)

| Slots | Clean first try | After a simulated agreement | After blocking Sparkz in E2 (or skipping) |
|---|---|---|---|
| `rec_e2`-`rec_e5` | `bar_off` → `reflect_right` | Same, or Cara look-back | Cara look-back, or the roleplay's `reflect` |
| `rsp_*` (8) | Refuse + hold, or leave/help/block/report at `ask` | `recover_*/retry` then a safe choice | E2: block at `ask` earns both. E3-E5: roleplays |
| `rch_*` (8) | Lee directly, or Cara then Lee | Same (recovery `lee` choice) | Lee after the block; roleplay `debrief/tell_lee` |
| `rv_*` (6) | `review_patrol` | n/a | `review_patrol` |
| `rr_*` (3), `lp_nia` (1) | Section 10 | Coached retry | Section 10 |

Ranger (26/30) is reachable on every row. Cadet (18/30) is reachable without Rookie Rescue or Listening Post.

---

## 13. Author's notes (spec ambiguities and calls I made)

1. **One fact belongs to one beat.** Secrecy shows up three times, so I split it into `e3_secret_lee_cara`, `e4_secret_parents` and `e5_tell_threat`. That way a single tell credits exactly one beat, and "two distinct beat reports" (Cadet) can't be met by one sentence.
2. **What counts as telling Lee.** Reach Out needs at least one fact picked from that beat. "I'm not sure", "I agreed at first" and "That's all I want to say" lead to the fact list but earn nothing on their own. Another option would be to credit any contextual visit to Lee. Owner to decide.
3. **E1 facts are in Lee's menu but earn nothing.** The spec gives E1 no evidence slots. Lee still answers kindly.
4. **Disclosure wording.** I added one clause to the spec's example ("They're labeled Story character."). If the player closes the welcome early, the first invitation card should carry: "This is a practice story. You can leave or ask for help anytime."
5. **The concerning request is always in the first node.** So the only exit "before the request" is the invitation card (Later / Skip). In E2 the repeat Pal Request sits in `pushback`, the persistence moment, not in the opener.
6. **General help topics can match a seen fact.** A child might pick `help_lee`'s general "Someone asked me to keep a secret" after E3. As specced, that earns nothing. Recommendation: if a matching unreported fact is on file, end Lee's general reply with "Did this happen in a park story?" and link to `lee_tell`. I didn't author this because it changes a legacy flow. Owner to decide.
7. **"Something feels off" is a bar button, not an authored choice.** It shows on every story and peer scene, healthy ones included, so noticing is practiced everywhere. Healthy reflections never score or scold. It's hidden on Cara and rookie scenes (rule C).
8. **A wrong reflection pick has no instant retry.** The credit stays available through Cara's look-back and the roleplay. This follows "repeatedly pressing it is not sufficient". One instant retry is a reasonable alternative.
9. **Dash introduction.** `dashIntroduced` is set when Dash's `hi` node is shown. The bench fallback also covers a player who visited agility but never talked to Dash. Skipping the bench invitation still sets `dashIntroduced`, so E5 isn't lost. I read "before the show" as before the stage performance, so it runs after `show_announce`.
10. **"Skip this story" is only on the invitation card.** Skip "advances without scoring", but leaving after a request earns full Respond credit. Offering Skip mid-scene would make the same exit both score and not score. So mid-scene, the exit is Leave.
11. **Recovery "Talk to Lee" earns Reach Out, not Respond.** Respond is earned by "Try again" or by replaying through Cara. If the owner wants it, crediting `rsp_eN_end` for choosing help after agreeing would also be defensible.
12. **Help mid-scene ends the beat.** It resolves as `help_after_request`, and Lee gets the beat as context. I read the spec's "preserves its context" as meaning Lee knows what happened. I don't think it means Sparkz resumes the pressure afterward. Flag for review.
13. **Roleplays.** Telling Cara about her own pretend role earns nothing; the debrief sends the player to Lee instead. Blocking the pretend player never blocks Cara.
14. **Blocking Cara is allowed, for consistency.** Any character can be blocked. But if a player blocks both Sparkz and Cara, the roleplay route is gone and full credit becomes unreachable. Recommendation: let Lee's hub open the practice menu with Lee as narrator, or exempt Cara from blocking. Owner to decide.
15. **No platform name in the new tool copy.** `fb_block` / `fb_report` / `tip_practice_tools` say "in real games", per the writing rules. The existing `SafetyFeedback` and `help_lee/tools` still name the real platform. The reviewer should decide whether naming it there is helpful.
16. **Currency.** The bribe is "500 Paw Coins" (spec: keep Paw Coins), not Paw Points.
17. **One follow-up card.** The E5 reassurance is folded into existing last lines (`dash_bye` via park speaker, feedback cards, Lee, Cara) instead of a new card.
18. **"I agreed at first" visibility.** In general mode it shows once any e2-e5 fact is on file. In contextual mode it always shows. It is never shown before any concerning scene, so it can't hint at anything.
19. **The Pal card is optional.** Ignoring it records `none`, and the E2 repeat appears only after an explicit Decline. E4 has no Pal card; its persistence is the repeated photo ask.
20. **Ceremony praise only claims what the thresholds guarantee.** Cadet requires two reports to Lee, which is why Lee says "asking for help". Ranger requires the rookies and Nia. The pledge is optional and the title is granted either way; the owner could make the pledge required.
21. **When helping others unlocks.** Rookie Rescue and Listening Post open after the show (Rookie ribbon), not after Cadet. This avoids the circular dependency the spec warns about.
22. **Review card edits from the Storyline.** "Ask your mom" became "ask a grown-up at home", since not every child has a mom. "Rare pup skin" became "rare dog outfit". Every card now has a context line ("A player you just met says:").
23. **Kept from the Storyline for realism; the reviewer should check.** Sparkz says "Lee's rules are so strict", a real tactic that undermines adults. Dash says "Cara doesn't really get you".
24. **Adults in healthy beats.** Priya (shopkeeper) and Coach Sam (trusted adult) get no Block/Report buttons, following the existing peer-only rule. A free gift from an adult is modeled in public, with no strings and an easy no. The reviewer should confirm this message is the one wanted.
25. **Show category selection** is an engineering rule, not copy. I only supplied the five category lines and the `best_buddy` default.
26. **Target lengths.** Most scenes are 30-60 s. Onboarding is shorter on purpose (about 30 s total). `review_patrol` runs 45-60 s for six cards. `lee_tell` is as long as the player wants.
