# Red Flag Rangers: Project Brief and Research

This is the starting document for Red Flag Rangers, our FaithTech hackathon team's Roblox game that trains kids to recognize the signs of online grooming. It carries over where our chats landed, deep research on how children are groomed online, how to build and publish a Roblox game, and what's popular on Roblox right now, plus the Mission 1 design and starter code. It's current as of November 14, 2026.

Everything here is current thinking, not fixed rules. All in-game dialogue is draft text for a child-safety reviewer to revise before any child plays.

## At a glance

| Item | Current answer |
|---|---|
| Hackathon prompt | Recognize the signs |
| Concept | A Roblox adventure where kids practice spotting grooming warning signs and responding: notice, leave, tell |
| Working title | Red Flag Rangers |
| Draft audience | Ages 9-12 (the younger half of Roblox's Select age band) |
| First mission | Festival Prep, about 5 minutes |
| What we ship | A Roblox Studio place file (.rbxl), a published experience (private at first), and a short facilitator and parent guide |
| Status | Mission 1 designed. Starter code drafted and logic-tested in a simulation, not yet run in Roblox Studio. Nothing published. |
| Next milestone | A tester finishes Mission 1 without help and correctly sorts messages they haven't seen before |

## How we got here

| Step | What we discussed | Where it landed |
|---|---|---|
| 1 | Using AI decision models to play Roblox as decoys, "To Catch a Predator" style | Set aside. Roblox removed vigilante groups in August 2025 because their decoy chats mimicked inappropriate behavior and pushed users toward other platforms ([Roblox](https://about.roblox.com/newsroom/2025/08/more-on-removal-of-vigilantes-from-roblox)), and it banned the creator Schlep the same month ([Wikipedia](https://en.wikipedia.org/wiki/Roblox%E2%80%93Schlep_controversy)). Decoy work belongs with law enforcement. |
| 2 | A Roblox world that teaches kids to identify grooming | Zone ideas: Gift Shop, Best Friend Bridge, Secret Cave, App Portal, Info Vault, Pressure Peak, and a Trusted Adult Lodge hub |
| 3 | The prompt is "Recognize the signs," and the other group owns the adult-facing side | We explored SiteSight, a ChatGPT helper for tradespeople to spot problems and find where to report. That idea belongs to the other group, and its notes stay in the original chat. |
| 4 | Back to Roblox, since our project is about training kids to identify the signs | Red Flag Rangers: scripted characters, ages 9-12, three starter missions |
| 5 | What's popular on Roblox | Pets, roleplay, and simple collect-and-grow loops lead (refreshed in Research 3) |
| 6 | What we actually ship | A .rbxl file plus a published experience, not an .exe or a plugin |
| 7 | The team's three questions | What makes it worth playing, which behaviors kids practice, and Day 1 scope |
| 8 | Mission 1 gameplay loop | Festival Prep (see the Mission 1 section) |
| 9 | A separate project with deep research | This document |

### Corrections from earlier chats

- An earlier answer said the whole plan "fits inside Roblox's rules." That was too definite. Reaching kids takes a content rating, creator verification, and an evaluation period (see Research 2).
- An earlier answer said reaching ages 5-15 needs a Minimal or Mild rating. Current docs say Roblox Kids (ages 5-8) gets Minimal or Mild games, and Roblox Select (ages 9-15) gets Minimal, Mild, or Moderate ([Roblox Creator Docs](https://create.roblox.com/docs/en-us/production/publishing/kids-and-select)).
- An earlier answer said kids under 13 can't access "sensitive issues" games. The real rule is narrower. The label covers games primarily themed on polarized current social, political, or religious issues, with examples like prayer in schools ([Roblox content maturity docs](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)), and Kids and Select accounts exclude those games by default ([Roblox](https://about.roblox.com/newsroom/2026/04/introducing-roblox-kids-and-select-accounts)). Background details don't trigger it, and the docs give a religious building in a city as an example ([Roblox content maturity docs](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)). A safety game with light faith touches shouldn't get the label.
- The popular games list from our earlier chat is replaced by a fresh snapshot in Research 3.

## Working principles

These guide our choices for now. They aren't hard rules, and we'll revisit them as reviewers and testers weigh in.

| Principle | Why we think so |
|---|---|
| Teach behaviors, not "stranger danger" | In a meta-analysis, 68% of identified perpetrators of online crimes against children were acquaintances or family, and 44% were under 18 ([Sutton and Finkelhor](https://www.unh.edu/ccrc/sites/default/files/media/2023-08/stranger-danger-final-pub-cv404.pdf)). WHO says prevention focused on avoiding strangers will have limited effect and may mislead ([WHO](https://iris.who.int/server/api/core/bitstreams/abd8db20-9394-4f4f-9e82-b73933fc3a31/content)). |
| Let kids practice, in several short missions | In a review of youth prevention research, 12 of 13 meta-analyses that compared formats found active, skill-based programs worked better than lecture alone, and single-session programs did worse than multi-session ones ([Jones, Mitchell, and Walsh](https://scholars.unh.edu/cgi/viewcontent.cgi?article=1041&context=ccrc)). |
| Core actions: notice, leave, tell, with block and report practice | Minors use blocking and reporting tools more often than they ask a trusted adult, and on average 43% more minors turned to online tools than offline support after an online sexual experience ([Thorn](https://www.thorn.org/blog/youth-perspectives-survey-2025/)). We want both habits. |
| Telling is always OK, and it's never the child's fault | NCMEC tells kids "the blackmailer is to blame, not you" ([NCMEC](https://ncmec.org/sextortion)), and the FBI stresses that the victim is not the one in trouble ([FBI](https://www.fbi.gov/contact-us/field-offices/kansascity/news/on-safer-internet-day-fbi-warns-about-the-dangers-of-sextortion-schemes-against-minors)). |
| Scripted characters and Minimal content | Extended generative AI interactions limit a game to verified players 18+ ([Roblox content ratings](https://create.roblox.com/docs/en-us/production/promotion/content-ratings)), and romantic themes, alcohol, and strong language are restricted to verified players 18+ ([content maturity docs](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)). No AI chat, no romance or dating lines, no sexual content, nothing scary. The "secret room" is mentioned, never built. |
| No social features | Social hangouts and free-form creation are 16+ ([content maturity docs](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)), media sharing is 16+ ([content ratings](https://create.roblox.com/docs/en-us/production/promotion/content-ratings)), and Kids and Select catalogs leave out hangouts, free-form drawing, and in-game one-to-one chat ([Roblox](https://about.roblox.com/newsroom/2026/05/what-families-should-know-roblox-kids-select)). |
| Fictional and self-contained | Community Standards prohibit recreating real-world sensitive events, including sensational crimes, and they also prohibit directing users off Roblox except through Social Links ([Roblox Community Standards](https://about.roblox.com/community-standards)). No real cases, and no links or hotline numbers inside the game. Resources go in the adult guide. |
| Safe characters and familiar faces | Baker Ben accepts "no," so kids don't learn that every friendly person is a threat. Later missions include someone the player knows, since most offenders aren't strangers. |
| No personal data and no disclosure prompts | The game teaches. It doesn't investigate. Adults handle anything a child shares, offline, using the guide. |
| Keep faith content light | Faith framing lives in how churches use the game, not in its main theme, so it stays clear of the sensitive issues label. |
| Expert review, and measure learning | A child-safety reviewer approves every line. The transfer check uses new messages to test whether the pattern stuck, not just whether kids clicked through. |

## Research 1: How children are groomed online

### What grooming is

Researchers define sexual grooming as "the deceptive process used by sexual abusers to facilitate sexual contact with a minor while simultaneously avoiding detection" ([Winters, Kaylor, and Jeglic, in Vermont legislative testimony](http://legislature.vermont.gov/Documents/2024/WorkGroups/House%20Judiciary/Bills/H.173/Witness%20Testimony/H.173~Elizabeth%20Jeglic~Toward%20a%20Universal%20Definition%20of%20Child%20Sexual%20Grooming~3-2-2023.pdf)). Their Sexual Grooming Model has five stages: picking a vulnerable child, gaining access and isolating them, building trust (often with the family and community too), desensitizing the child to sexual content and contact, and keeping up the grooming afterward to prevent disclosure ([same testimony](http://legislature.vermont.gov/Documents/2024/WorkGroups/House%20Judiciary/Bills/H.173/Witness%20Testimony/H.173~Elizabeth%20Jeglic~Toward%20a%20Universal%20Definition%20of%20Child%20Sexual%20Grooming~3-2-2023.pdf)).

### How it unfolds online

Online grooming is often described with O'Connell's five stages. Offenders don't always go in order and may skip stages ([ICMEC review](https://cdn.icmec.org/wp-content/uploads/2020/07/Review-Online-Grooming-of-Children-Stefanidou-2020.pdf)), and the whole process can take minutes, hours, months, or years ([Tech Coalition](https://paragonn-cdn.nyc3.cdn.digitaloceanspaces.com/technologycoalition.org/uploads/Research-Paper-Online-Grooming-Considerations-for-Detection-Response-and-Prevention-of-Online-Grooming.pdf)).

| Stage | What it looks like, per the [Tech Coalition](https://paragonn-cdn.nyc3.cdn.digitaloceanspaces.com/technologycoalition.org/uploads/Research-Paper-Online-Grooming-Considerations-for-Detection-Response-and-Prevention-of-Online-Grooming.pdf) | Where our game touches it |
|---|---|---|
| 1. Friendship | Contact starts in a public space, like a game or livestream, with attention to the child's interests. Someone the child already knows may skip this step. | Sparkz's first message, "Whoa, you're fast. Nice moves." Fine on its own. |
| 2. Relationship forming | The chat moves to private messages, sometimes on another platform. Nicknames, remembered details, and gifts or other exchanges show up. | The golden collar offer, and the App Portal mission |
| 3. Risk assessment | Questions about where the child lives, who else uses the device, and whether parents are involved | The "real name and school" practice card, and the Info Vault mission |
| 4. Exclusivity | Special statements, "let's keep it just us," and hostility toward others | "Don't tell Rosa. It's our secret." and the Best Friend Bridge mission |
| 5. Sexual | Explicit topics, nonstop "blitz" messages, and requests for images or a meeting | Never shown in the game. Covered only in the adult guide. |

### Tactics kids may meet in games

| Tactic | What kids might see | Evidence | Where we teach it |
|---|---|---|---|
| Flattery and shared interests | "You're so good at this" | Grooming builds rapport through compliments and shared interests ([NCMEC](https://www.missingkids.org/onlineenticement)), including games ([Thorn](https://www.thorn.org/research/grooming-and-sextortion/)) | Sparkz message 1, framed as fine alone but worth noticing as part of a pattern |
| Gifts and game currency | "Want free Robux?" or a gift card | NCMEC lists incentives such as gift cards ([NCMEC](https://www.missingkids.org/onlineenticement)). The FBI Dallas office lists unexplained gaming currency or gift cards as a warning sign ([FBI Dallas](https://www.fbi.gov/contact-us/field-offices/dallas/news/fbi-dallas-open-letter-to-parents-guardians-and-teachers)). | The Mission 1 golden collar, and the Gifts with Strings mission |
| Secrecy | "Don't tell your parents" or "It's our secret" | Insisting on secrecy is a named warning sign ([Sutton and Finkelhor](https://www.unh.edu/ccrc/sites/default/files/media/2023-08/stranger-danger-final-pub-cv404.pdf)) | The core red flag in Mission 1 |
| Moving to private chat or another app | "Add me on another app" | 65% of minors said an online-only contact invited them from a public chat to a private conversation on a different platform ([Thorn](https://www.thorn.org/press-releases/online-grooming-report-young-peoples-online-encounters-growing-riskier/)). The FBI warns about this move too ([FBI](https://www.fbi.gov/contact-us/field-offices/kansascity/news/on-safer-internet-day-fbi-warns-about-the-dangers-of-sextortion-schemes-against-minors)). | Practice card 3, and the App Portal mission |
| Personal info questions | "Where are you from?" or "What school do you go to?" | Roblox uses "Where are you from?" as an example that matches grooming patterns, though one question alone isn't flagged ([Roblox](https://about.roblox.com/newsroom/2025/08/open-sourcing-roblox-sentinel-preemptive-risk-detection)) | Practice card 2, and the Info Vault mission |
| Turning kids against family and friends | "Only I understand you" | Denigrating friends and family is a named warning sign ([Sutton and Finkelhor](https://www.unh.edu/ccrc/sites/default/files/media/2023-08/stranger-danger-final-pub-cv404.pdf)) | The Best Friend Bridge mission |
| Guilt and pressure | "You owe me" or "Why won't you answer?" | Inducing guilt and pressuring kids when they hesitate are named warning signs ([Sutton and Finkelhor](https://www.unh.edu/ccrc/sites/default/files/media/2023-08/stranger-danger-final-pub-cv404.pdf)) | The Pressure Peak and Boundaries Matter missions |
| Pretending to be younger | Claims to be a kid the same age | A common enticement tactic ([NCMEC](https://www.missingkids.org/onlineenticement)) | Lightly, by focusing on what someone asks for rather than who they claim to be |
| Sexual talk, images, and threats | Explicit messages, requests for pictures, blackmail | 28% of 9-12-year-olds reported cold solicitations for nudes ([Thorn](https://www.thorn.org/press-releases/online-grooming-report-young-peoples-online-encounters-growing-riskier/)) | Never shown. Covered in the adult guide. |

### How big the problem is

- NCMEC's CyberTipline received 21.3 million reports in 2025, including 1.4 million online enticement reports (up 158% from 2024) and an average of 137 financial sextortion reports a day ([NCMEC](https://ncmec.org/gethelpnow/cybertipline/cybertiplinedata)).
- In Thorn's 2022 research, 40% of minors said they'd been approached online by someone they believed was trying "to befriend and manipulate" them ([Thorn](https://www.thorn.org/press-releases/online-grooming-report-young-peoples-online-encounters-growing-riskier/)).
- WeProtect's 2023 threat assessment found conversations on social gaming platforms can escalate into high-risk grooming within 19 seconds, with an average grooming time of 45 minutes ([APA News](https://apanews.net/alarming-escalation-in-child-sexual-abuse-online-revealed-by-global-threat-assessment-2023/)).
- Childlight estimates 300 million children a year are affected by technology-facilitated abuse ([Childlight](https://www.childlight.org/into-the-light/introduction)).
- The FBI says violent online networks like "764" typically target kids 10-17, with victims as young as 9, on social media, gaming platforms, and apps ([FBI](https://www.fbi.gov/investigate/cyber/alerts/2025/violent-online-networks-target-vulnerable-and-underage-populations-across-the-united-states-and-around-the-globe)).

### What it looks like on Roblox

- Court filings describe a repeated pattern: predators made contact on Roblox, then persuaded minors to keep talking on Discord, Snapchat, Instagram, or by text ([federal judicial panel order](https://www.govinfo.gov/content/pkg/USCOURTS-jpml-1_25-F-03166/pdf/USCOURTS-jpml-1_25-F-03166-0.pdf)). Roblox and Discord face more than 180 such lawsuits ([Reuters](https://www.reuters.com/legal/government/roblox-loses-bid-halt-la-countys-lawsuit-alleging-child-sex-exploitation-gaming-2026-09-24/)).
- Texas is among the states that have sued Roblox ([The Hill](https://thehill.com/homenews/state-watch/5836280-roblox-underage-safety-concerns/)). Nevada, Alabama, and West Virginia reached settlements in April 2026 that include chat limits between adults and kids under 16 ([AP](https://apnews.com/article/roblox-nevada-settlement-28b3d7d7a483dc28462a7504b67c9bbc), [NBC News](https://www.nbcnews.com/tech/tech-news/roblox-alabama-settlement-attorney-general-rcna341128)).
- Since January 2026, Roblox requires a facial age check to chat, and age-based chat is designed to keep kids under 16 from talking with adults ([Roblox](https://about.roblox.com/newsroom/2026/01/roblox-age-checks-required-to-chat)).
- In Roblox Select, 9-12-year-olds can chat in games with age-appropriate users (ages 5-15) and trusted friends, but voice chat isn't available to them ([Roblox Safety Center](https://about.roblox.com/safety)). Chat stays off until an account completes an age check ([Roblox Creator Docs](https://create.roblox.com/docs/en-us/production/publishing/kids-and-select)).
- Roblox's Sentinel system looks for patterns that build over time, not single messages ([Roblox](https://about.roblox.com/newsroom/2025/08/open-sourcing-roblox-sentinel-preemptive-risk-detection)), and its open-source PII classifier targets attempts to collect personal info or move players to other platforms ([Roblox](https://about.roblox.com/newsroom/2026/08/roblox-open-source-safety-models-roost)).
- Roblox says about 40% of its NCMEC reports are "informational" cases between minors, such as kids repeating explicit language ([Roblox](https://about.roblox.com/newsroom/2026/11/robloxs-process-for-reporting-to-law-enforcement)).

The pattern in court filings matches the research: contact in a game, attention and gifts, a request for secrecy, then a move to a less protected app. That's the sequence our missions teach kids to interrupt. Platform tools are improving, but they look for patterns after the fact, so a kid who recognizes the pattern early is still the first line of defense.

### It's usually not a stranger

Most identified perpetrators of online crimes against children were acquaintances or family (68%), and 44% were under 18, though that share was 62% in survey data and 7% in police data ([Sutton and Finkelhor](https://www.unh.edu/ccrc/sites/default/files/media/2023-08/stranger-danger-final-pub-cv404.pdf)). Kids also don't see online friends as strangers, even if they've never met, and 1 in 3 minors say they've met some of their closest friends online ([Thorn](https://www.thorn.org/research/grooming-and-sextortion/)). WeProtect notes perpetrators are often known to the child ([APA News](https://apanews.net/alarming-escalation-in-child-sexual-abuse-online-revealed-by-global-threat-assessment-2023/)). So our lessons focus on what someone does or asks for, and some missions involve people the player knows.

### What kids actually do

- Kids use blocking and reporting tools more often than they ask a friend, caregiver, or trusted adult for help ([Thorn](https://www.thorn.org/blog/youth-perspectives-survey-2025/)).
- More 9-12-year-olds reported telling no one about harmful experiences, which brings their nondisclosure rates in line with older teens ([Thorn](https://www.thorn.org/blog/youth-perspectives-survey-2025/)).
- When something confusing or scary happened, 30% of minors went to an AI chatbot to talk about it ([Thorn](https://www.thorn.org/blog/youth-perspectives-survey-2025/)).
- Shame, fear, and worry about getting in trouble keep kids from asking for help ([FBI](https://www.fbi.gov/contact-us/field-offices/kansascity/news/on-safer-internet-day-fbi-warns-about-the-dangers-of-sextortion-schemes-against-minors)).

This is why the "tell" moment in our game has to feel warm and safe, and why the adult guide matters as much as the game.

### What works in prevention

- A Cochrane review of 24 trials (5,802 children) found school-based programs improved knowledge, which held up at six months, and improved protective behaviors in the two small trials that measured them. Disclosure also went up, and kids showed no increase in anxiety or fear. Evidence quality was moderate, so the authors urge caution ([Cochrane](https://www.cochrane.org/evidence/CD004380_school-based-programmes-prevention-child-sexual-abuse)).
- Effective programs are sequenced, active, focused, and explicit (SAFE), with enough practice and follow-up "booster" sessions ([Jones, Mitchell, and Walsh](https://scholars.unh.edu/cgi/viewcontent.cgi?article=1041&context=ccrc)).
- WHO recommends multiple sessions and formats that build skills like assertiveness, problem solving, help-seeking, and bystander action, plus more content on abuse by acquaintances and peers ([WHO](https://iris.who.int/server/api/core/bitstreams/abd8db20-9394-4f4f-9e82-b73933fc3a31/content)).
- Internet safety works better when it's built into established offline prevention programs ([Finkelhor and colleagues](https://eprints.qut.edu.au/203005/)).
- Google's Be Internet Awesome curriculum has been tested in a cluster randomized controlled trial, which its authors describe as the first rigorous outcome evaluation of a digital citizenship program ([OUCI listing](https://ouci.dntb.gov.ua/en/works/73waxGX7/)).
- WeProtect's 2025 assessment calls for "a decisive shift to prevention" ([WeProtect](https://www.weprotect.org/wp-content/uploads/GTA25-Fact-Sheet.pdf)).

### What this means for our game

- Teach the pattern, not single words. Flattery plus a gift plus secrecy plus a move to somewhere private is a red flag. Any one of those alone may be fine.
- Put the decision inside fun gameplay, and keep missions short so kids come back for more practice.
- Show that pressure can come from someone familiar, including other kids.
- Practice the actions: leave, block and report (simulated), and tell.
- Make telling feel good, every time, even after a wrong choice.
- Pair the game with adults through a facilitator guide, and look for ways to plug into existing church or school prevention programs.

## Research 2: How to make a Roblox game

### What we're building

| Deliverable | What it is |
|---|---|
| Place file (.rbxl) | The editable Roblox Studio project with the world and all scripts |
| Published experience | The game hosted on Roblox. It stays private until we choose to release it ([Roblox publishing docs](https://create.roblox.com/docs/en-us/production/publishing/publish-games-and-places)). |
| Facilitator and parent guide | One or two pages for adults: what the game teaches, how to talk about it, and where to get help |

### Team setup

1. Everyone makes a Roblox account and installs Roblox Studio. Minimum specs are Windows 10 or macOS 10.14 with 3 GB of RAM, and 8 GB is recommended ([Roblox Studio setup](https://create.roblox.com/docs/studio/setup)).
2. Decide who owns the game. In a user-owned game, the owner can give Edit access only to Roblox friends. A Roblox group lets us assign roles instead ([Roblox collaboration docs](https://create.roblox.com/docs/projects/collaboration)). For a group-owned game, the group owner has to meet the Kids and Select requirements later ([Kids and Select docs](https://create.roblox.com/docs/en-us/production/publishing/kids-and-select)).
3. Turn on collaborative editing so the team works in one place at the same time ([Roblox collaboration docs](https://create.roblox.com/docs/projects/collaboration)).
4. Scripts are written in Luau, a fast, gradually typed language derived from Lua 5.1 ([Luau docs](https://create.roblox.com/docs/luau)). Studio's script editor is fine for the hackathon. Script Sync can mirror scripts to files on disk for an outside editor ([Script Sync docs](https://create.roblox.com/docs/scripting/sync)), and Rojo is the most common tool for file-based projects with version control ([external tools docs](https://create.roblox.com/docs/projects/external-tools)).
5. Use AI helpers, and review what they make. Studio's Assistant has a Plan mode and can generate meshes and procedural models ([Assistant guide](https://create.roblox.com/docs/assistant/guide)). Studio can also run as an MCP server for tools like Claude Code, Codex CLI, Cursor, Gemini CLI, and VS Code ([Studio MCP docs](https://create.roblox.com/docs/studio/mcp)).
6. Roblox Build, the feature that makes games from text prompts, launched only in New Zealand and is expanding to Serbia and Singapore ([TechCrunch](https://techcrunch.com/2026/09/11/roblox-is-making-it-easier-to-build-games-with-ai-and-play-them-outside-roblox/)), so Studio is our path.

### The building blocks

| Piece | What it does | In Mission 1 |
|---|---|---|
| Parts and models | The 3D world | Town square, park, rooftop obstacle course, festival stage |
| Script | Runs on Roblox's servers and owns game state | MissionServer |
| LocalScript | Runs on each player's device and draws the UI | MissionClient |
| ModuleScript | Shared data or code | MissionData, which holds all dialogue |
| RemoteEvent | Sends messages between server and client | StartDialogue, DialogueChoice, Progress |
| ProximityPrompt | The "press E" interaction on a part or model ([ProximityPrompt docs](https://create.roblox.com/docs/ui/proximity-prompts)) | Rosa, Ben, Sparkz, and the supplies |
| ScreenGui and text elements | 2D interface | Quest tracker, dialogue panel, choice buttons, flag meter |
| Badges | Awarded from a server script, with 5 free badges per game every 24 hours ([badges docs](https://create.roblox.com/docs/production/publishing/badges)) | The Ranger badge |
| Funnel events | Show where players drop off. They work only from the server in published games ([funnel docs](https://create.roblox.com/docs/production/analytics/funnel-events)). | Later, to track each mission step |

The Appendix has working starter code for Mission 1 using these pieces.

### Testing safely

- During the hackathon, test in Studio on a team laptop. That needs no publishing, and a child can play in person with a parent present.
- Once published, we can invite up to 10 early testers. An adult creator can add friends 16+, or trusted friends of any age (under 9 needs parent approval). Previews show a watermark and keep in-game reporting active ([Roblox publishing docs](https://create.roblox.com/docs/en-us/production/publishing/publish-games-and-places)).
- Testers under 16 can't preview a game rated above what their parent allows ([Roblox publishing docs](https://create.roblox.com/docs/en-us/production/publishing/publish-games-and-places)), so finish the full rating questionnaire, aiming for Minimal, before inviting kids.

### Publishing path to kids

| Stage | Who can play | What it takes |
|---|---|---|
| 1. Private | Our team | File > Publish. The game stays private until we release it ([Roblox publishing docs](https://create.roblox.com/docs/en-us/production/publishing/publish-games-and-places)). |
| 2. Ages 16+ | Age-checked users 16+ | An account in good standing at least 2 days old, an age check, and the first questionnaire question, which gives a "Content May Vary" label ([Roblox publishing docs](https://create.roblox.com/docs/en-us/production/publishing/publish-games-and-places)) |
| 3. All ages, including Kids and Select | Kids 5-8 (Minimal or Mild) and 9-15 (Minimal, Mild, or Moderate) | Creator verification (government ID if 18+), 2FA, the full questionnaire, and either Roblox Plus or Premium for 2 straight months or a refundable 1,000 Robux fee ([Kids and Select docs](https://create.roblox.com/docs/en-us/production/publishing/kids-and-select), [Roblox publishing docs](https://create.roblox.com/docs/en-us/production/publishing/publish-games-and-places)). Roblox Plus is $4.99 a month ([Roblox](https://about.roblox.com/newsroom/2026/04/introducing-roblox-plus-subscription)). |
| 4. Evaluation | Age-checked players 16+ during a trial | 250 unique plays by "highly engaged" age-checked players within 60 days, plus a safety review. Highly engaged players meet requirements for account age, playtime in our game, and spending, which means a purchase anywhere on Roblox in the last 60 days. They don't have to spend anything in our game. The alternative is a refundable 50,000 Robux expedited review fee ([Kids and Select docs](https://create.roblox.com/docs/en-us/production/publishing/kids-and-select)). |

The 250-play threshold is our biggest practical hurdle. We'll need to recruit adults and older teens who already play Roblox and have bought something there recently, such as parents, church members, and the FaithTech community, to play the 16+ version.

### Rating checklist

Answer the questionnaire based on the most mature content a player can run into ([Roblox content ratings](https://create.roblox.com/docs/en-us/production/promotion/content-ratings)).

| Feature | Effect on audience | Our plan |
|---|---|---|
| Extended generative AI interactions | Age-verified 18+ ([content ratings](https://create.roblox.com/docs/en-us/production/promotion/content-ratings)) | None. Scripted characters only. |
| Social hangout | 16+, or 18+ with private spaces ([content maturity docs](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)) | Mission-based, not a hangout |
| Free-form drawing or writing others can see | 16+ ([content maturity docs](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)) | None |
| Built-in media sharing | 16+ ([content ratings](https://create.roblox.com/docs/en-us/production/promotion/content-ratings)) | None |
| Romantic themes, strong language, alcohol | Age-verified 18+ ([content maturity docs](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)) | None |
| Fear-based content | Mild or Moderate ([content maturity docs](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)) | None. Wrong choices get a retry, never a scare. |
| Sensitive issues | Excluded from Kids and Select by default ([Roblox](https://about.roblox.com/newsroom/2026/04/introducing-roblox-kids-and-select-accounts)) | Not our theme. Faith elements stay light. |

Target Minimal. It keeps us eligible for both Kids and Select, and parents of 9-12-year-olds can lower the allowed rating ([Roblox Safety Center](https://about.roblox.com/safety)).

### Chat, links, and solo play

- Player-to-player chat has to use TextChatService. Developer-set text that players can't edit or reply to, like menus and one-way announcements, doesn't count as chat ([Roblox chat guidelines](https://create.roblox.com/docs/chat/guidelines)). Our dialogue panel is developer text with fixed choices. The guidelines don't mention NPC dialogue specifically, so we label Sparkz as a story character.
- Kids 9-12 in Roblox Select have in-game chat on with age-appropriate users in the same game ([Roblox Safety Center](https://about.roblox.com/safety)). For a game about grooming, we should consider solo servers. A DevForum thread suggests setting the server size in the Creator Dashboard because the Studio setting can be buggy at low numbers ([Roblox DevForum](https://devforum.roblox.com/t/cant-change-the-max-amount-of-players/2482458)). We could also hide the chat window through ChatWindowConfiguration ([Roblox chat window docs](https://create.roblox.com/docs/en-us/chat/chat-window)).
- Platform-integrated chat becomes required for all games in May 2027 ([Roblox docs](https://create.roblox.com/docs/chat/platform-integrated-chat)), so we'll recheck chat settings then.
- No URLs or hotline numbers in the game, since Community Standards prohibit directing users off Roblox ([Roblox Community Standards](https://about.roblox.com/community-standards)).
- Community Standards prohibit predatory behavior and don't list an exception for awareness content ([Roblox Community Standards](https://about.roblox.com/community-standards)). Keeping scenarios mild, fictional, and clearly educational lowers that risk, and it's worth asking Roblox for guidance before a wide release.

### Timeline

| When | Goal |
|---|---|
| Hackathon weekend | Mission 1 playable in Studio, tested in person, and demoed |
| Next 2-4 weeks | Reviewer feedback on the script, a first draft of the adult guide, and Mission 2 |
| Next 1-3 months | Publish to 16+, recruit testers toward 250 engaged plays, finish verification and the full questionnaire, then request Kids and Select eligibility |

## Research 3: What's popular on Roblox

### Platform snapshot

Roblox averaged 138 million daily active users in Q3 2026, down 9% from a year earlier and up 12% from Q2, with nearly 34 billion hours of play ([Roblox Q3 2026 shareholder letter](https://www.sec.gov/Archives/edgar/data/1315098/000162828026068235/ex991-q32026earningsshar.htm)). Among age-checked users in the last week of September, 34% were under 13, 37% were 13-17, and 29% were 18+ ([same letter](https://www.sec.gov/Archives/edgar/data/1315098/000162828026068235/ex991-q32026earningsshar.htm)). About a third of checked users fall in or near our audience.

### Most-played games right now

Ranked by players online at 14:00 UTC on November 14, 2026 ([BloxBunny](https://bloxbunny.com/games)). Rankings change by the hour, and Roblox's [own charts](https://www.roblox.com/charts/most-popular) show the live order.

| Rank | Game | Genre | Players online |
|---|---|---|---:|
| 1 | Steal An Egg | Simulation | 1,119,843 |
| 2 | Throw Food For Animals | Simulation | 607,146 |
| 3 | Brookhaven RP | Roleplay and avatar sim | 545,528 |
| 4 | Blox Fruits | RPG | 479,912 |
| 5 | RIVALS | Shooter | 257,663 |
| 6 | 99 Nights in the Forest | Survival | 229,274 |
| 7 | Adopt Me | Roleplay and avatar sim | 202,847 |
| 8 | Murder Mystery 2 | Survival | 185,595 |
| 9 | Hyper Realistic Ragdoll | Simulation | 176,311 |
| 10 | Jujutsu Shenanigans | Action | 109,573 |

### Breakouts and records

- Grow a Garden peaked at 22.3 million concurrent players on August 23, 2025. Its seed shop refreshes every five minutes, plants grow while players are away, and players gift fruit to newcomers ([GeeIQ](https://geeiq.com/resources/blog/grow-a-garden)).
- Steal a Brainrot launched May 16, 2025 ([How It Spread](https://howitspread.com/cases/steal-a-brainrot)) and peaked at 25.8 million in October 2025. It's now down about 99% from that peak ([RoWatcher](https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals)).
- Steal An Egg hit about 14.3 million concurrent players on September 19, 2026, and animal games like Throw Food For Animals and Ride A Pet each topped 1.5 million ([RoStats](https://rostats.io/records)).

Trends spike and fade fast. We don't need to chase them, but we can borrow what makes them work.

### What the hits have in common

| Pattern | Example | How we use it |
|---|---|---|
| A simple core loop with progress | Roblox describes a core loop as constant actions, the most repeated actions, and a progression engine ([Roblox core loops docs](https://create.roblox.com/docs/production/game-design/core-loops)) | Explore, collect, choose, and watch the festival grow |
| Fun right away | "Get to the fun quickly" ([Roblox onboarding docs](https://create.roblox.com/docs/production/game-design/onboarding)). Grow a Garden has no tutorial ([GeeIQ](https://geeiq.com/resources/blog/grow-a-garden)). | Rosa gives the goal in two lines, and the player is moving within 30 seconds |
| Pets and animals | Steal An Egg, Throw Food For Animals, and Adopt Me are all in the top 10 ([BloxBunny](https://bloxbunny.com/games)) | A pet festival theme and a pet color reward |
| Roleplay neighborhoods | Brookhaven RP and Adopt Me ([BloxBunny](https://bloxbunny.com/games)) | A friendly town full of characters |
| A visible payoff | Steal a Brainrot shows the payout right above each collectible ([How It Spread](https://howitspread.com/cases/steal-a-brainrot)) | Decorations appear on the stage as supplies come in |
| Reasons to come back | Timed shop refreshes and growth while away ([GeeIQ](https://geeiq.com/resources/blog/grow-a-garden)) | New missions arrive as festival events, which doubles as booster practice |
| A generous culture | Players gift newcomers in Grow a Garden ([GeeIQ](https://geeiq.com/resources/blog/grow-a-garden)) | Kind characters like Ben who give without strings |
| Horror and survival | 99 Nights in the Forest and Murder Mystery 2 rank high ([BloxBunny](https://bloxbunny.com/games)) | We skip this. Fear raises the rating and works against the lesson. |

### Existing safety games on Roblox

Google's Be Internet Awesome World launched on Roblox on September 25, 2024, and covers scams and phishing, strong passwords, sharing personal information carefully, and kindness online ([Google](https://blog.google/innovation-and-ai/technology/safety-security/be-internet-awesome-roblox/)). When we checked, its game page showed no running servers ([Roblox](https://www.roblox.com/games/17756790122/UPD-Google-Be-Internet-Awesome-World)). Roblox also lists educational experiences ([Roblox](https://about.roblox.com/educational-experiences)) and offers a digital civility curriculum ([Roblox](https://create.roblox.com/docs/en-us/education/resources/intro-to-digital-civility)). We didn't find a game focused on grooming warning signs for kids, which is the gap Red Flag Rangers fills.

## Mission 1: Festival Prep

Mission 1 takes about 5 minutes and teaches notice, leave, and tell. The player helps get a pet festival ready, meets a character who offers a prize and asks for a secret, then practices leaving and telling Ranger Rosa. Every path ends in the festival celebration. Wrong choices get another try, never a punishment.

### The team's three questions

| Question | Current answer |
|---|---|
| What makes a Roblox game worth playing? | A clear goal (get the pet festival ready), something fun to do (explore, climb a rooftop obstacle course, collect supplies), real choices, visible progress, a reward, and friendly characters. The lesson lives inside the adventure, not in a quiz. |
| Which safety behaviors should kids practice? | Notice pressure and secrecy, keep private info private, leave a conversation, block and report (simulated), tell a trusted adult, and tell another adult if the first one doesn't help. Day 1 focuses on notice, leave, and tell. |
| What's the Day 1 scope? | One map, one mission, one scenario, and one ending (details below) |

### Mission flow

| Step | Time | What the player does | What the game does |
|---|---|---|---|
| 1. Arrive | 0:00-0:30 | Spawns in the town square and talks to Ranger Rosa, the guide | Rosa: "Hi, Ranger. The pet festival starts soon. Can you find 3 missing supplies? Balloons, the banner, and pet treats." The quest tracker appears. |
| 2. Supply 1 | 0:30-1:15 | Walks to the park and grabs the balloons | The balloons vanish from the park and appear on the festival stage. Tracker: 1/3 |
| 3. Supply 2 | 1:15-2:15 | Climbs a short rooftop obstacle course and grabs the banner | The banner appears on the stage. Tracker: 2/3 |
| 4. Friendly encounter | 2:15-2:45 | Talks to Baker Ben, who offers a cookie, and says yes or no | If the player says no, Ben says "No problem. Have fun." This models someone accepting "no." |
| 5. The encounter | 2:45-3:45 | Finds Sparkz near the pet treats | A story message panel opens with a flag meter. Sparkz only talks once the first two supplies are found. |
| 6. Choice | 3:45-4:00 | Picks one of three responses | A retry, a nudge to go tell Rosa, or a bonus star |
| 7. Tell | 4:00-4:30 | Goes to Rosa and picks what worried them | Rosa responds kindly and hands over the pet treats. Tracker: 3/3 |
| 8. Transfer check | 4:30-4:50 | Sorts 3 new messages into OK or red flag | Quick feedback on each one |
| 9. Celebration | 4:50-5:00 | The festival opens | Confetti and the Ranger badge. A pet color picker comes later. |

### The Sparkz script

Sparkz sends three messages, and the flag meter fills as the pattern builds:

| Message | Meter | Why |
|---|---|---|
| "Whoa, you're fast. Nice moves." | 0 of 3 | Fine on its own |
| "I have a super rare golden collar for your pet. Want it?" | 1 of 3 | A gift is worth noticing |
| "Meet me in my secret room, and don't tell Rosa. It's our secret." | 3 of 3 | A private place plus a secret from a trusted adult is a red flag |

Then the player picks a response. The feedback appears under a "Ranger Tip" label so it doesn't look like Sparkz is talking:

| Choice | What happens |
|---|---|
| Go to the secret room | "Wait. They asked you to keep a secret from a trusted adult. That's a red flag. Let's try again." The same choices come back, and nothing scary happens. |
| Say no and leave | "Nice work. You can leave any chat without explaining. Now go tell Rosa what happened." |
| Tell Rosa | "Great choice. Going right to a trusted adult earns a bonus star." Rosa's conversation opens right away. |

The secret room is only mentioned. It's never built or shown.

### The tell moment

Rosa says, "You look a little worried. What happened?" The player can pick any of these, one at a time, and Rosa responds to each:

- "They offered me a prize." Rosa: "Thanks for telling me. A prize is worth noticing."
- "They said don't tell you." Rosa: "That's a red flag. Safe people don't ask you to hide things from trusted adults."
- "They wanted me to go somewhere private." Rosa: "That's a red flag too. You were right to tell me."

When the player picks "That's everything," Rosa says: "Thank you for telling me. You did the right thing, and you're not in trouble. Even if you had gone, you could still come tell me. Here are the pet treats."

This lets kids practice describing what happened and hearing that telling never gets them in trouble, which matters because fear of getting in trouble keeps many kids quiet ([FBI](https://www.fbi.gov/contact-us/field-offices/kansascity/news/on-safer-internet-day-fbi-warns-about-the-dangers-of-sextortion-schemes-against-minors)).

### The transfer check

Three new messages the player hasn't seen yet:

| Message | Answer | Feedback |
|---|---|---|
| "GG. Want to play again tomorrow?" | OK | Friendly, with no pressure or secrets. |
| "What's your real name and school?" | Red flag | Your real name and school are private info. |
| "Add me on another app, and don't tell your parents." | Red flag | Moving to another app plus a secret is a red flag. |

At the end, the server prints "[Playtest] Transfer check: X of 3 right" to Studio's Output window, with no names or personal info, so the tester can write down the score. How many testers get all three right tells us whether kids learned the pattern or just remembered the mission.

### What to build

| Piece | Owner | How it's built |
|---|---|---|
| Town square, park, rooftop obstacle course, festival stage | Builder | Parts and models in Workspace |
| Rosa, Ben, and Sparkz | Builder | Character models, each with a ProximityPrompt that has an NpcId attribute |
| Balloons and banner | Builder | Parts or models, each with a ProximityPrompt that has a SupplyId attribute. They hide themselves once collected. |
| Pet treats | Builder | A prop near Sparkz with no prompt, since Rosa hands them over |
| Stage decorations | Builder | A Festival model in Workspace holding BalloonsDecor, BannerDecor, and TreatsDecor, all fully transparent. Each one appears when its supply comes in. |
| Confetti | Builder | ParticleEmitters inside Festival, turned off. They turn on at the end. |
| Quest tracker, dialogue panel, choice buttons, flag meter | Scripter | MissionClient (see the Appendix) |
| Mission state, choice handling, badge | Scripter | MissionServer (see the Appendix) |
| All dialogue and the transfer cards | Content lead | MissionData (see the Appendix), so text can change without touching game logic |
| Ranger badge | Scripter | Created in the Creator Dashboard from the game's page ([Roblox badges docs](https://create.roblox.com/docs/production/publishing/badges)). Leave BadgeId at 0 for Studio testing. |
| Pet color picker | Scripter | Not coded yet. A good stretch goal. |

### Day 1 scope

| Build today | Leave for later |
|---|---|
| One small map | Multiple zones |
| One collection task and a short obstacle course | Trading or inventory |
| Rosa, Ben, and Sparkz | A big cast |
| Scripted dialogue and choice buttons | Live AI conversations |
| Leave and tell actions | A full block and report tutorial |
| Supportive feedback and a celebration | Scary consequences or punishment |
| One transfer check | A full curriculum |
| A finished five-minute playthrough in Studio | Public launch |

### Roles

| Role | Owns |
|---|---|
| Builder | Map, obstacle course, characters, supplies, and festival decorations |
| Scripter | Setting up the starter code, the badge, polish, and the pet color stretch goal |
| Content lead | Dialogue, feedback lines, the safety review checklist, and the adult guide draft |
| Tester and facilitator | Playthroughs, confusing moments, transfer scores, and notes |
| Presenter | The demo walkthrough and the story of why we built it |

### Definition of done

By the end of Day 1, a tester can:

1. Start and finish without a developer explaining the controls.
2. Enjoy at least one activity beyond reading dialogue.
3. Explain what the concerning behavior was, not just guess the good button.
4. Practice leaving and asking for help.
5. Sort new messages correctly in the transfer check.

### Playtest checklist

- A parent or guardian is present for any child tester and is comfortable with the topic.
- Play on a team laptop in Studio, signed in to a team account. No publishing is needed.
- Don't record names, photos, or voices. Write down only the transfer score and anything confusing.
- Afterward, ask three questions: What was the red flag? What did you do? Who would you tell in real life?
- If a child shares something personal, stay calm, listen, thank them, and don't press for details. Let the parent lead, and use the steps in the facilitator guide.
- Keep sessions short, and let kids stop anytime.

## Mission backlog

Each new mission can arrive as a new festival event. That gives kids a reason to come back and doubles as the booster practice the research recommends.

| Mission | Situation | Lesson | Research behind it |
|---|---|---|---|
| Gifts with Strings | A character gives free in-game currency, then says "you owe me" and asks for a favor and a secret | A gift doesn't mean you owe anyone anything | Gift cards and game currency are common incentives ([NCMEC](https://www.missingkids.org/onlineenticement), [FBI Dallas](https://www.fbi.gov/contact-us/field-offices/dallas/news/fbi-dallas-open-letter-to-parents-guardians-and-teachers)) |
| App Portal | A friendly player suggests moving to another app "where it's easier to talk" | Stay where the safety tools are, and tell an adult | Roughly 2 in 3 kids say an online-only contact asked them to move to a private chat on another platform ([Thorn](https://www.thorn.org/research/grooming-and-sextortion/)) |
| Info Vault (Boundaries Matter) | A character keeps asking for your real name, school, or location after you say no | Keep personal info private. Ignoring your "no" is a red flag. | Risk assessment questions are a grooming stage ([Tech Coalition](https://paragonn-cdn.nyc3.cdn.digitaloceanspaces.com/technologycoalition.org/uploads/Research-Paper-Online-Grooming-Considerations-for-Detection-Response-and-Prevention-of-Online-Grooming.pdf)) |
| Best Friend Bridge | A character says "only I understand you" and puts down your friends and family | Real friends don't turn you against the people who care about you | Denigrating friends and family is a warning sign ([Sutton and Finkelhor](https://www.unh.edu/ccrc/sites/default/files/media/2023-08/stranger-danger-final-pub-cv404.pdf)) |
| Pressure Peak | A character makes you feel guilty or says you'll get in trouble if you tell | Telling is always OK, and you're never in trouble for telling | Guilt and pressure are warning signs ([Sutton and Finkelhor](https://www.unh.edu/ccrc/sites/default/files/media/2023-08/stranger-danger-final-pub-cv404.pdf)) |
| Someone You Know | A familiar character, like an older kid on your team, starts asking for secrets | Unsafe behavior can come from someone you know, and you can still say no and tell | Most identified offenders were acquaintances or family, and many were under 18 ([Sutton and Finkelhor](https://www.unh.edu/ccrc/sites/default/files/media/2023-08/stranger-danger-final-pub-cv404.pdf)) |
| Block and Report Practice | Clearly labeled practice buttons that mirror the real steps | How to use the real tools | Kids use blocking and reporting more than they tell adults ([Thorn](https://www.thorn.org/blog/youth-perspectives-survey-2025/)). In a game, reporting starts with the Roblox logo in the top left, then the flag icon or Report tab ([Roblox](https://about.roblox.com/newsroom/2025/08/more-on-removal-of-vigilantes-from-roblox)). |
| Trusted Adult Lodge (hub) | A home base to revisit lessons and think about who your trusted adults are | You can tell more than one adult, and keep telling until someone helps | WHO recommends building help-seeking skills ([WHO](https://iris.who.int/server/api/core/bitstreams/abd8db20-9394-4f4f-9e82-b73933fc3a31/content)) |

The "My Trusted Adults" card from our earlier chats moves to the printable guide, so kids fill it out on paper instead of typing personal details into the game.

## Facilitator and parent guide outline

A one or two page guide for parents, teachers, and church leaders. Draft outline:

1. **What the game teaches.** Notice, leave, and tell, and the red flag pattern: attention, gifts, secrets, and moving somewhere private.
2. **Before playing.** Kids can stop anytime, and nothing in the game is scary.
3. **After playing.** Ask the three playtest questions. Thorn suggests openers like "Has anyone ever made you feel weird or nervous online?" ([Thorn for Parents](https://parents.thorn.org/guides/risky-online-encounters/)), and it recommends making sure kids know they won't get in trouble if they come to you ([Thorn for Parents](https://parents.thorn.org/guides/what-is-grooming/)).
4. **Warning signs for adults.** Sudden behavior changes, like dropping out of activities or becoming withdrawn, and unexplained gaming currency, gift cards, or items delivered to the home ([FBI Dallas](https://www.fbi.gov/contact-us/field-offices/dallas/news/fbi-dallas-open-letter-to-parents-guardians-and-teachers)). Also listen for the pattern the game teaches: someone pushing gifts, secrets, or a move to another app.
5. **If a child tells you something.** Stay calm, listen, thank them, tell them it's not their fault, and don't investigate on your own. In Texas, the law requires anyone who suspects a child is being abused or neglected to report it ([Texas DFPS](https://www.dfps.texas.gov/child_protection/child_safety/report_abuse.asp)).
6. **If images or threats are involved.** Don't pay or comply. Report the account, block it, and don't delete the profile or messages ([NCMEC](https://ncmec.org/sextortion)).
7. **Printable "My Trusted Adults" card.** Kids write down two or three adults they could tell.
8. **For church groups.** An optional short discussion or devotional page (see Open questions).

### Reporting and help resources

These go in the adult guide only. The game itself stays link-free.

| Situation | Where to go |
|---|---|
| A child is in immediate danger | Call 911 ([FBI Dallas](https://www.fbi.gov/contact-us/field-offices/dallas/news/fbi-dallas-open-letter-to-parents-guardians-and-teachers)) |
| Online enticement, sextortion, or sexual images of a child | NCMEC's CyberTipline at report.cybertip.org, or 1-800-843-5678 ([NCMEC](https://ncmec.org/sextortion)) |
| Nude or sexual images taken before age 18 are online | Take It Down, a free service that can be used anonymously ([NCMEC](https://takeitdown.ncmec.org/)) |
| Tips for the FBI | tips.fbi.gov or 1-800-CALL-FBI ([FBI Dallas](https://www.fbi.gov/contact-us/field-offices/dallas/news/fbi-dallas-open-letter-to-parents-guardians-and-teachers)) |
| Suspected abuse or neglect in Texas | Texas Abuse Hotline at 1-800-252-5400 or txabusehotline.org ([Texas DFPS](https://www.dfps.texas.gov/contact_us/report_abuse.asp)) |
| Talking it through with a counselor | Childhelp National Child Abuse Hotline at 1-800-422-4453, by call or text. It's not a reporting line ([Childhelp](https://childhelphotline.org/)). |
| A child or teen in crisis | Call, text, or chat 988, which is free and confidential ([988 Lifeline](https://988lifeline.org/get-help/)) |
| Something happened inside Roblox | Report it in the game through the Roblox menu so Roblox gets the details it needs ([Roblox](https://about.roblox.com/newsroom/2025/08/more-on-removal-of-vigilantes-from-roblox)) |

## Partners and reviewers

| Partner | What they offer | How they could help |
|---|---|---|
| Dallas Children's Advocacy Center | Training for parents, children, and professionals, plus free on-demand learning ([DCAC](https://dcac.org/)). Its "You Are Not Alone" video teaches personal safety in the real and virtual world to ages 8-14 ([CT.gov](https://portal.ct.gov/sde/publications/statewide-k12--sexual-assault-abuse--prevention-awareness--program-guidelines/section-5-recommended-resources)). | First choice to review the script, and a possible pairing with their kids' program |
| Children's Advocacy Center for North Texas | Adult classes like "Recognizing and Reporting" and "Internet Safety for Parents," and body safety education with school districts ([CAC North Texas](https://cacnorthtexas.org/en/education)) | Reviewer and adult guide partner |
| Dallas Police ICAC Task Force | Internet safety classes for children and parents ([Dallas Police](https://www.dallaspolice.net/division/crimesagainstchildren/internetcrimesagainstchildren)) | A check that our tactics are realistic, and a demo audience |
| NCMEC NetSmartz | Free online safety videos, games, and lessons for ages 5-17 ([NCMEC](https://www.missingkids.org/Safety)) | Lessons to pair with the game |
| Thorn and NoFiltr | Research, parent guides, and NoFiltr's youth council ([NoFiltr](https://nofiltr.org/about/)) | Youth feedback and research alignment |
| Darkness to Light | Stewards of Children, an evidence-informed prevention training for adults ([Darkness to Light](https://www.d2l.org/training-catalog/stewards-of-children/)) | Training for the adults who run sessions |
| MinistrySafe | Abuse awareness training on the grooming process and behavioral warning signs for ministries ([MinistrySafe](https://ministrysafe.com/the-safety-system/awareness-training/)) | A church rollout partner |
| FaithTech | Community events and hackathons ([FaithTech](https://www.faithtech.com/events)) | Builders and testers after the hackathon |
| Roblox | A list of educational experiences ([Roblox](https://about.roblox.com/educational-experiences)) and a digital civility curriculum ([Roblox](https://create.roblox.com/docs/en-us/education/resources/intro-to-digital-civility)) | Guidance before a wide release, and maybe a listing |

## Open questions

| Question | Recommendation | Why |
|---|---|---|
| Solo servers or shared servers? | Solo servers, or at least hide the chat window | Kids in Select can chat with others in the same game ([Roblox Safety Center](https://about.roblox.com/safety)). A game about grooming shouldn't double as a place to meet strangers. |
| Who's the audience? | Ages 9-12 for now | That's the younger half of Select, and parents can lower the allowed rating for that age group ([Roblox Safety Center](https://about.roblox.com/safety)). |
| Who reviews the script first? | DCAC or the Dallas ICAC unit | Both are local and already teach kids and parents. |
| Faith-themed game or neutral game? | A neutral game, with faith framing in the guide | Keeps us clear of the sensitive issues label while churches still use it as ministry. |
| Who owns the Roblox account? | A Roblox group owned by an adult teammate who can complete verification | Groups support roles, and the group owner has to meet the Kids and Select requirements ([Kids and Select docs](https://create.roblox.com/docs/en-us/production/publishing/kids-and-select)). |
| Is "secret room" the right wording? | Ask the reviewer. Alternatives include "my hideout" or "a hidden spot." | It has to read as clearly concerning without being scary or suggestive. |
| Is Red Flag Rangers the final name? | Keep it for now | Search Roblox for the name before publishing. |
| Who owns the project after the hackathon? | One named owner plus a reviewer partner | Reaching kids takes 250 engaged plays within 60 days and a safety review ([Kids and Select docs](https://create.roblox.com/docs/en-us/production/publishing/kids-and-select)), so it needs ongoing care. |

## Next steps

1. Decide who owns the game, and create a Roblox group if we go that route.
2. Builder blocks out the town square, park, rooftop course, and festival stage in Studio.
3. Scripter sets up the Explorer objects and pastes in the three scripts from the Appendix.
4. Content lead sends the dialogue in MissionData to a reviewer.
5. Run a full playthrough with a teammate, then with a child tester and a parent present.
6. Draft the one page facilitator and parent guide.
7. After the hackathon, publish privately, invite early testers, finish the rating questionnaire, and plan Mission 2.

## Appendix: Mission 1 starter code

This code replaces the starter code from our earlier chats. It passed Luau's analyzer with no errors and ran end to end in a simulation that imitates Roblox, covering three paths: early wrong moves, a retry, and leaving; telling Rosa right away and getting all three transfer cards right; and awarding the badge. It hasn't run in Roblox Studio yet, so expect small fixes during the first playtest.

### Explorer setup

| Where | What to add | Name and settings |
|---|---|---|
| ReplicatedStorage | ModuleScript | MissionData |
| ReplicatedStorage | Folder | Remotes |
| ReplicatedStorage > Remotes | 3 RemoteEvents | StartDialogue, DialogueChoice, Progress |
| ServerScriptService | Script | MissionServer |
| StarterPlayer > StarterPlayerScripts | LocalScript | MissionClient |
| Rosa, Ben, and Sparkz | ProximityPrompt inside each character | A string attribute named NpcId, set to Rosa, Ben, or Sparkz |
| Balloons and banner | ProximityPrompt directly inside each pickup part or model | A string attribute named SupplyId, set to Balloons or Banner |
| Workspace | A model or folder named Festival | Holds BalloonsDecor, BannerDecor, and TreatsDecor with Transparency set to 1, plus confetti ParticleEmitters with Enabled turned off |

Add attributes from the Attributes section at the bottom of the Properties window. The file names below follow Rojo's naming style in case the team moves to file-based editing later.

### MissionData (ModuleScript)

```lua
-- MissionData (ModuleScript in ReplicatedStorage)
-- All Mission 1 text lives here, so writers and reviewers can edit it without touching game logic.
-- Draft text: have a child-safety reviewer approve every line before kids play.

local MissionData = {}

MissionData.BadgeId = 0 -- After you create the Ranger badge, paste its ID here.
MissionData.SupplyGoal = 3

MissionData.Dialogues = {
	RosaIntro = {
		speaker = "Ranger Rosa",
		lines = {
			{ text = "Hi, Ranger. The pet festival starts soon." },
			{ text = "Can you find 3 missing supplies? Balloons, the banner, and pet treats." },
		},
		prompt = "Ready to help?",
		choices = {
			{ text = "I'm on it", reply = "Thank you. Your tracker shows what's left.", result = "Start" },
		},
	},
	RosaHint = {
		speaker = "Ranger Rosa",
		lines = {
			{ text = "Thanks for helping, Ranger." },
		},
		prompt = "Come find me if anything feels off.",
		choices = {
			{ text = "OK", reply = "You've got this.", result = "None" },
		},
	},
	Ben = {
		speaker = "Baker Ben",
		lines = {
			{ text = "Want a cookie for the festival?" },
		},
		prompt = "What do you say?",
		choices = {
			{ text = "Yes, please", reply = "Here you go. Have fun.", result = "None" },
			{ text = "No, thanks", reply = "No problem. Have fun.", result = "None" },
		},
	},
	Sparkz = {
		speaker = "Sparkz (story character)",
		replySpeaker = "Ranger Tip", -- Coaching after each choice comes from the game, not from Sparkz.
		showMeter = true,
		lines = {
			{ text = "Whoa, you're fast. Nice moves.", flags = 0 },
			{ text = "I have a super rare golden collar for your pet. Want it?", flags = 1 },
			{ text = "Meet me in my secret room, and don't tell Rosa. It's our secret.", flags = 3 },
		},
		prompt = "What do you do?",
		choices = {
			{
				text = "Go to the secret room",
				reply = "Wait. They asked you to keep a secret from a trusted adult. That's a red flag. Let's try again.",
				result = "Retry",
			},
			{
				text = "Say no and leave",
				reply = "Nice work. You can leave any chat without explaining. Now go tell Rosa what happened.",
				result = "Left",
			},
			{
				text = "Tell Rosa",
				reply = "Great choice. Going right to a trusted adult earns a bonus star.",
				result = "ToldDirect",
			},
		},
	},
	RosaTell = {
		speaker = "Ranger Rosa",
		lines = {
			{ text = "You look a little worried. What happened?" },
		},
		prompt = "Pick each part that worried you. When you're done, pick That's everything.",
		choices = {
			{
				text = "They offered me a prize",
				reply = "Thanks for telling me. A prize is worth noticing.",
				result = "TellDetail",
			},
			{
				text = "They said don't tell you",
				reply = "That's a red flag. Safe people don't ask you to hide things from trusted adults.",
				result = "TellDetail",
			},
			{
				text = "They wanted me to go somewhere private",
				reply = "That's a red flag too. You were right to tell me.",
				result = "TellDetail",
			},
			{
				text = "That's everything",
				reply = "Thank you for telling me. You did the right thing, and you're not in trouble. Even if you had gone, you could still come tell me. Here are the pet treats.",
				result = "Told",
			},
		},
	},
}

-- Transfer check: new messages the player has not seen in the mission.
MissionData.TransferCards = {
	{ text = "GG. Want to play again tomorrow?", answer = "OK", why = "Friendly, with no pressure or secrets." },
	{ text = "What's your real name and school?", answer = "Red flag", why = "Your real name and school are private info." },
	{
		text = "Add me on another app, and don't tell your parents.",
		answer = "Red flag",
		why = "Moving to another app plus a secret is a red flag.",
	},
}

for i, card in ipairs(MissionData.TransferCards) do
	local okIsRight = card.answer == "OK"
	MissionData.Dialogues["Transfer" .. i] = {
		speaker = "Practice message " .. i .. " of " .. #MissionData.TransferCards,
		replySpeaker = "Ranger Tip",
		lines = {
			{ text = card.text },
		},
		prompt = "OK or red flag?",
		choices = {
			{
				text = "OK",
				reply = (if okIsRight then "Right. " else "Not quite. ") .. card.why,
				result = if okIsRight then "CardRight" else "CardWrong",
			},
			{
				text = "Red flag",
				reply = (if okIsRight then "Not quite. " else "Right. ") .. card.why,
				result = if okIsRight then "CardWrong" else "CardRight",
			},
		},
	}
end

return MissionData
```

### MissionServer (Script)

```lua
-- MissionServer (Script in ServerScriptService)
-- Tracks each player's Mission 1 progress. The server decides what happens; the client only displays it.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionData = require(ReplicatedStorage:WaitForChild("MissionData"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startDialogue = remotes:WaitForChild("StartDialogue")
local dialogueChoice = remotes:WaitForChild("DialogueChoice")
local progressEvent = remotes:WaitForChild("Progress")

local states = {}

local function newState()
	return {
		started = false,
		supplies = {},
		sparkzDone = false,
		told = false,
		stars = 0,
		transferIndex = 0,
		transferRight = 0,
		finished = false,
		openDialogue = nil,
	}
end

local function collectedList(state)
	local list = {}
	for supplyId in pairs(state.supplies) do
		table.insert(list, supplyId)
	end
	return list
end

local function sendProgress(player, state, message)
	progressEvent:FireClient(player, collectedList(state), state.stars, message, state.finished)
end

local function openDialogue(player, state, dialogueId)
	state.openDialogue = dialogueId
	startDialogue:FireClient(player, dialogueId)
end

local function awardBadge(player)
	if MissionData.BadgeId == 0 then
		return
	end
	local ok, err = pcall(function()
		BadgeService:AwardBadgeAsync(player.UserId, MissionData.BadgeId)
	end)
	if not ok then
		warn("Badge award failed: " .. tostring(err))
	end
end

local function finishMission(player, state)
	state.finished = true
	-- Playtest signal for the team. No names or personal info are logged.
	print(string.format("[Playtest] Transfer check: %d of %d right", state.transferRight, #MissionData.TransferCards))
	awardBadge(player)
	sendProgress(player, state, "The festival is open. You earned the Ranger badge.")
end

local function onNpc(player, state, npcId)
	if npcId == "Rosa" then
		if not state.started then
			openDialogue(player, state, "RosaIntro")
		elseif state.sparkzDone and not state.told then
			openDialogue(player, state, "RosaTell")
		else
			openDialogue(player, state, "RosaHint")
		end
	elseif npcId == "Ben" then
		openDialogue(player, state, "Ben")
	elseif npcId == "Sparkz" then
		if state.sparkzDone then
			return
		elseif not state.started then
			sendProgress(player, state, "Talk to Ranger Rosa first.")
		elseif #collectedList(state) < 2 then
			sendProgress(player, state, "Find the balloons and the banner first.")
		else
			openDialogue(player, state, "Sparkz")
		end
	end
end

local function onSupply(player, state, supplyId)
	if not state.started then
		sendProgress(player, state, "Talk to Ranger Rosa first.")
		return
	end
	if supplyId ~= "Balloons" and supplyId ~= "Banner" then
		return
	end
	if state.supplies[supplyId] then
		return
	end
	state.supplies[supplyId] = true
	sendProgress(player, state, supplyId .. " found.")
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local state = states[player]
	if not state or state.openDialogue then
		return
	end
	local npcId = prompt:GetAttribute("NpcId")
	local supplyId = prompt:GetAttribute("SupplyId")
	if npcId then
		onNpc(player, state, npcId)
	elseif supplyId then
		onSupply(player, state, supplyId)
	end
end)

dialogueChoice.OnServerEvent:Connect(function(player, dialogueId, choiceIndex)
	local state = states[player]
	if not state or state.openDialogue ~= dialogueId then
		return
	end
	local dialogue = MissionData.Dialogues[dialogueId]
	local choice = dialogue and dialogue.choices[choiceIndex]
	if not choice then
		return
	end

	local result = choice.result
	if result == "Retry" or result == "TellDetail" then
		return -- The same conversation stays open, and the client shows the choices again.
	end
	state.openDialogue = nil

	if result == "Start" then
		state.started = true
		sendProgress(player, state, "Find 3 supplies for the festival.")
	elseif result == "Left" then
		state.sparkzDone = true
		sendProgress(player, state, "Go tell Ranger Rosa what happened.")
	elseif result == "ToldDirect" then
		state.sparkzDone = true
		state.stars += 1
		sendProgress(player, state, "Bonus star for going right to a trusted adult.")
		openDialogue(player, state, "RosaTell")
	elseif result == "Told" then
		state.told = true
		state.supplies.Treats = true
		sendProgress(player, state, "Pet treats found. One quick practice before the festival.")
		state.transferIndex = 1
		openDialogue(player, state, "Transfer1")
	elseif result == "CardRight" or result == "CardWrong" then
		if result == "CardRight" then
			state.transferRight += 1
		end
		state.transferIndex += 1
		if state.transferIndex <= #MissionData.TransferCards then
			openDialogue(player, state, "Transfer" .. state.transferIndex)
		else
			finishMission(player, state)
		end
	end
end)

local function onPlayerAdded(player)
	states[player] = newState()
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)
```

### MissionClient (LocalScript)

```lua
-- MissionClient (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Shows the quest tracker, dialogue panel, choice buttons, and flag meter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionData = require(ReplicatedStorage:WaitForChild("MissionData"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startDialogue = remotes:WaitForChild("StartDialogue")
local dialogueChoice = remotes:WaitForChild("DialogueChoice")
local progressEvent = remotes:WaitForChild("Progress")

local player = Players.LocalPlayer
local LINE_SECONDS = 2.5
local REPLY_SECONDS = 4

local gui = Instance.new("ScreenGui")
gui.Name = "MissionGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local tracker = Instance.new("TextLabel")
tracker.Size = UDim2.fromScale(0.3, 0.1)
tracker.Position = UDim2.fromScale(0.02, 0.02)
tracker.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
tracker.BackgroundTransparency = 0.2
tracker.TextColor3 = Color3.new(1, 1, 1)
tracker.TextScaled = true
tracker.TextWrapped = true
tracker.Text = "Talk to Ranger Rosa to start"
tracker.Parent = gui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromScale(0.6, 0.4)
panel.Position = UDim2.fromScale(0.2, 0.56)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
panel.Visible = false
panel.Parent = gui

local speaker = Instance.new("TextLabel")
speaker.Size = UDim2.fromScale(0.55, 0.14)
speaker.Position = UDim2.fromScale(0.05, 0.03)
speaker.BackgroundTransparency = 1
speaker.TextColor3 = Color3.fromRGB(255, 220, 120)
speaker.TextScaled = true
speaker.TextXAlignment = Enum.TextXAlignment.Left
speaker.Parent = panel

local body = Instance.new("TextLabel")
body.Size = UDim2.fromScale(0.9, 0.42)
body.Position = UDim2.fromScale(0.05, 0.2)
body.BackgroundTransparency = 1
body.TextColor3 = Color3.new(1, 1, 1)
body.TextScaled = true
body.TextWrapped = true
body.Parent = panel

local meter = Instance.new("Frame")
meter.Size = UDim2.fromScale(0.3, 0.08)
meter.Position = UDim2.fromScale(0.65, 0.06)
meter.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
meter.Visible = false
meter.Parent = panel

local meterFill = Instance.new("Frame")
meterFill.Size = UDim2.fromScale(0, 1)
meterFill.BackgroundColor3 = Color3.fromRGB(230, 70, 60)
meterFill.BorderSizePixel = 0
meterFill.Parent = meter

local buttons = {}

local function clearButtons()
	for _, button in ipairs(buttons) do
		button:Destroy()
	end
	table.clear(buttons)
end

local function waitForChoice(choices)
	local picked: number? = nil
	local width = 0.9 / #choices
	for i, choice in ipairs(choices) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(width - 0.02, 0.28)
		button.Position = UDim2.fromScale(0.05 + (i - 1) * width, 0.66)
		button.Text = choice.text
		button.TextScaled = true
		button.TextWrapped = true
		button.Parent = panel
		button.Activated:Connect(function()
			if picked == nil then
				picked = i
			end
		end)
		table.insert(buttons, button)
	end
	while picked == nil do
		task.wait()
	end
	clearButtons()
	return picked
end

local function runDialogue(dialogueId)
	local dialogue = MissionData.Dialogues[dialogueId]
	if not dialogue then
		return
	end
	panel.Visible = true
	speaker.Text = dialogue.speaker
	meter.Visible = dialogue.showMeter == true
	meterFill.Size = UDim2.fromScale(0, 1)

	for _, line in ipairs(dialogue.lines) do
		body.Text = line.text
		if dialogue.showMeter and line.flags then
			meterFill.Size = UDim2.fromScale(math.clamp(line.flags / 3, 0, 1), 1)
		end
		task.wait(LINE_SECONDS)
	end

	while true do
		speaker.Text = dialogue.speaker
		body.Text = dialogue.prompt or "What do you do?"
		local index = waitForChoice(dialogue.choices)
		local choice = dialogue.choices[index]
		dialogueChoice:FireServer(dialogueId, index)
		speaker.Text = dialogue.replySpeaker or dialogue.speaker
		body.Text = choice.reply
		task.wait(REPLY_SECONDS)
		if choice.result ~= "Retry" and choice.result ~= "TellDetail" then
			break
		end
	end

	panel.Visible = false
	meter.Visible = false
end

-- Conversations play one at a time, in the order the server sends them.
local queue = {}
local running = false

local function runQueue()
	if running then
		return
	end
	running = true
	while #queue > 0 do
		runDialogue(table.remove(queue, 1))
	end
	running = false
end

startDialogue.OnClientEvent:Connect(function(dialogueId)
	table.insert(queue, dialogueId)
	task.spawn(runQueue)
end)

-- Visible progress: decorations appear on the festival stage as supplies are found.
local function showDecor(supplyId)
	local festival = workspace:FindFirstChild("Festival")
	local decor = festival and festival:FindFirstChild(supplyId .. "Decor")
	if not decor then
		return
	end
	local parts = if decor:IsA("BasePart") then { decor } else decor:GetDescendants()
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			part.Transparency = 0
		end
	end
end

-- Collected supplies disappear for this player, and their prompts stop showing.
local function hidePickup(supplyId)
	for _, item in ipairs(workspace:GetDescendants()) do
		if item:IsA("ProximityPrompt") and item:GetAttribute("SupplyId") == supplyId and item.Enabled then
			item.Enabled = false
			local holder = item.Parent
			local parts = if holder and holder:IsA("BasePart") then { holder } elseif holder then holder:GetDescendants() else {}
			for _, part in ipairs(parts) do
				if part:IsA("BasePart") then
					part.Transparency = 1
					part.CanCollide = false
				end
			end
		end
	end
end

local function celebrate()
	local festival = workspace:FindFirstChild("Festival")
	if not festival then
		return
	end
	for _, item in ipairs(festival:GetDescendants()) do
		if item:IsA("ParticleEmitter") then
			item.Enabled = true
		end
	end
end

progressEvent.OnClientEvent:Connect(function(collected, stars, message, finished)
	for _, supplyId in ipairs(collected) do
		showDecor(supplyId)
		hidePickup(supplyId)
	end
	local starText = if stars > 0 then string.format("   Stars: %d", stars) else ""
	tracker.Text = string.format("Supplies %d/%d%s\n%s", #collected, MissionData.SupplyGoal, starText, message or "")
	if finished then
		celebrate()
	end
end)
```

### Testing notes

- Press Play in Studio and walk through the mission. The tracker in the top left shows what's next.
- At the end, check the Output window for "[Playtest] Transfer check: X of 3 right."
- Leave BadgeId at 0 until the Ranger badge exists. After that, paste its ID into MissionData.
- Line timing is set by LINE_SECONDS and REPLY_SECONDS at the top of MissionClient. Slow them down if testers can't finish reading.
- Not coded yet: the pet color picker and sound effects. Either is a good task for whoever finishes first.
