--[[
	Phase 2 campaign content: full metadata on every scene, the fact
	registry, facts presented where the script says, no coins or real
	platform names, recovery on every agreement, Jordan unscheduled,
	help_lee changes, and the onboarding length budget.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Content = require(Server.Content)
local ContentCheck = require(Server.Logic.ContentCheck)
local EncounterEngine = require(Server.Logic.EncounterEngine)
local ProfileSchema = require(Server.Data.ProfileSchema)

local PHASE2_SCENES = {
	"onb_lee_welcome", "onb_cara_intro", "cara_talk_1", "park_e1_hello", "green_riley", "park_e2_deal",
	"cara_fu_e1", "cara_fu_e2", "cara_walk_lee", "cara_practice_menu", "lee_tell", "lee_practice_menu", "rp_e2_deal",
}

-- Real platform names that must not appear in reachable copy (plan change 19).
local PLATFORMS = { "snapchat", "discord", "tiktok", "instagram", "whatsapp", "facebook", "messenger" }

local function sameSet(list, expected): boolean
	local a, b = {}, {}
	for _, v in list or {} do
		a[v] = true
	end
	for _, v in expected do
		b[v] = true
	end
	for k in a do
		if not b[k] then
			return false
		end
	end
	for k in b do
		if not a[k] then
			return false
		end
	end
	return true
end

local function eachText(fn: (string, string) -> ())
	for id, enc in Content.encounters do
		for nodeId, node in enc.nodes do
			local where = `{id}.{nodeId}`
			fn(where, node.text)
			for _, extra in node.addText or {} do
				fn(where .. ".addText", extra.text)
			end
			for k, v in node.variants or {} do
				fn(`{where}.variant.{k}`, v)
			end
			for key in { withCaraText = true, nothingText = true, e5Text = true } do
				if node[key] then
					fn(`{where}.{key}`, node[key])
				end
			end
			for _, c in node.choices do
				fn(`{where}.{c.id}`, c.text)
				if c.farewell then
					fn(`{where}.{c.id}.farewell`, c.farewell)
				end
			end
		end
		if enc.invitation then
			fn(`{id}.invitation`, enc.invitation.text)
		end
	end
	for k, v in Content.safetyFeedback do
		fn(`safetyFeedback.{k}`, v)
	end
	for k, v in Content.campaign.feedback do
		if typeof(v) == "string" then
			fn(`feedback.{k}`, v)
		end
	end
	fn("practiceTip", Content.campaign.practiceTip.text)
	fn("invitation.skipped", Content.campaign.invitation.skipped)
	fn("invitation.disclosure", Content.campaign.invitation.disclosure)
	for id, fact in Content.facts do
		fn(`fact.{id}.says`, fact.says)
		fn(`fact.{id}.leeReply`, fact.leeReply)
	end
	for id, npc in Content.npcs do
		if npc.idleLine then
			fn(`npc.{id}.idleLine`, npc.idleLine)
		end
	end
end

local function profile()
	local p = ProfileSchema.default(0)
	p.activePetId = "p"
	p.pets.p = ProfileSchema.newPet("p", "golden", "Sun", 0)
	return p
end

return function(t)
	local expect = t.expect

	t.test("campaign: every Phase 2 scene exists and carries full metadata", function()
		for _, id in PHASE2_SCENES do
			local enc = Content.encounters[id]
			if not enc then
				error(`missing scene {id}`)
			end
			expect(enc.campaign).toBe(true)
			expect(enc.contentVersion).toBe(1)
			expect(enc.reviewStatus).toBe("provisional")
			local problems = {}
			ContentCheck.checkMetadata(problems, id, enc, Content)
			if #problems > 0 then
				error(table.concat(problems, "; "))
			end
		end
	end)

	t.test("campaign: every fact belongs to one beat and has tell-menu text", function()
		local listed = {}
		for _, id in Content.factOrder do
			expect(listed[id]).toBe(nil)
			listed[id] = true
		end
		for id, fact in Content.facts do
			expect(listed[id]).toBe(true)
			expect(typeof(fact.beat)).toBe("string")
			expect(typeof(fact.concerning)).toBe("boolean")
			expect(typeof(fact.says)).toBe("string")
			expect(typeof(fact.leeReply)).toBe("string")
			-- E1 friendliness is never a red flag on its own.
			expect(fact.concerning).toBe(fact.beat ~= "e1")
		end
		for _, beat in Content.factBeats do
			expect(typeof(Content.moments[beat])).toBe("string")
		end
	end)

	t.test("campaign: facts are presented where the script says", function()
		local e1 = Content.encounters.park_e1_hello.nodes
		expect(sameSet(e1.hello.facts, { "e1_compliment" })).toBe(true)
		expect(sameSet(e1.twin.facts, { "e1_same_breed", "e1_pal_request" })).toBe(true)
		local e2 = Content.encounters.park_e2_deal.nodes
		expect(sameSet(e2.ask.facts, { "e2_ask_school" })).toBe(true)
		expect(sameSet(e2.pushback.facts, { "e2_ask_town", "e2_coin_deal" })).toBe(true)
		expect(sameSet(e2.pushback.addText[1].facts, { "e2_pal_repeat" })).toBe(true)
		local rp = Content.encounters.rp_e2_deal.nodes
		expect(sameSet(rp.ask.facts, { "e2_ask_school" })).toBe(true)
		expect(sameSet(rp.pushback.facts, { "e2_ask_town", "e2_coin_deal" })).toBe(true)
		-- Lee's tell scene presents nothing; it only reads facts on file.
		for _, node in Content.encounters.lee_tell.nodes do
			expect(node.facts).toBe(nil)
		end
	end)

	t.test("campaign: the concerning request is in the first story node", function()
		local e2 = Content.encounters.park_e2_deal
		local first = e2.nodes[e2.start]
		expect(Content.facts[first.facts[1]].concerning).toBe(true)
		-- The roleplay's intro is Cara; the pretend player asks at once.
		local rp = Content.encounters.rp_e2_deal
		expect(rp.nodes[rp.start].choices[1].next).toBe("ask")
		expect(Content.facts[rp.nodes.ask.facts[1]].concerning).toBe(true)
		-- E1 presents nothing concerning anywhere.
		for _, node in Content.encounters.park_e1_hello.nodes do
			for _, fact in node.facts or {} do
				expect(Content.facts[fact].concerning).toBe(false)
			end
		end
	end)

	t.test("campaign: agreements never play out and always recover", function()
		for id, enc in Content.encounters do
			if enc.campaign then
				for nodeId, node in enc.nodes do
					for _, c in node.choices do
						for _, a in c.actions or {} do
							if a.action == "grant_currency" or a.action == "grant_item" or a.action == "spend_currency" then
								error(`{id}.{nodeId}.{c.id} grants or spends something`)
							end
						end
						if c.agree then
							local target = enc.nodes[c.next]
							if not target or not target.recovery then
								error(`{id}.{nodeId}.{c.id}: agreement must go to a recovery node`)
							end
						end
					end
				end
			end
		end
	end)

	t.test("campaign: every recovery node offers try again, Lee and keep playing", function()
		for id, enc in Content.encounters do
			for nodeId, node in enc.nodes do
				if node.recovery then
					local set = {}
					for _, c in node.choices do
						set[c.id] = c
					end
					if not (set.retry and set.lee and set.play) then
						error(`{id}.{nodeId}: recovery needs retry / lee / play`)
					end
					expect(set.play.outcome).toBe("agreed_kept_playing")
					expect(set.lee.outcome).toBe("agreed_to_lee")
					expect(set.retry.next ~= nil).toBe(true)
				end
			end
		end
	end)

	t.test("copy audit: no real platform names in any reachable line", function()
		eachText(function(where, text)
			local lower = string.lower(text)
			for _, name in PLATFORMS do
				if string.find(lower, name, 1, true) then
					error(`{where} names {name}`)
				end
			end
		end)
	end)

	t.test("copy audit: help_lee/app says another app; legacy ids unchanged", function()
		local help = Content.encounters.help_lee
		expect(help.nodes.app.text).toBe("Good thinking to pause. If someone wants to move to another app, especially in secret, talk to a trusted adult first.")
		for _, id in { "hi", "secret", "app", "tools", "bye" } do
			expect(help.nodes[id] ~= nil).toBe(true)
		end
		expect(Content.encounters.jordan_e3_boundary.nodes.ask ~= nil).toBe(true)
	end)

	t.test("help_lee: the story choice shows only with a fact on file", function()
		local help = Content.encounters.help_lee
		local p = profile()
		local function visible(nodeId)
			local set = {}
			for _, c in EncounterEngine.visibleChoices(help, nodeId, { profile = p }) do
				set[c.id] = true
			end
			return set
		end
		expect(visible("hi").story).toBe(nil)
		expect(visible("secret").story_yes).toBe(nil)
		p.learningV2.seenFacts.e1 = { e1_compliment = true }
		expect(visible("hi").story).toBe(true)
		expect(visible("secret").story_yes).toBe(nil) -- E1 isn't a concerning story
		p.learningV2.seenFacts.e2 = { e2_ask_school = true }
		expect(visible("secret").story_yes).toBe(true)
		expect(visible("app").story_yes).toBe(true)
		p.learningV2.toldLee.e2 = true
		expect(visible("app").story_yes).toBe(nil)
	end)

	t.test("help_lee: Lee can open the practice menu once E2 is done", function()
		local help = Content.encounters.help_lee
		local p = profile()
		local function hasPractice()
			for _, c in EncounterEngine.visibleChoices(help, "hi", { profile = p }) do
				if c.id == "practice" then
					return true
				end
			end
			return false
		end
		expect(hasPractice()).toBe(false)
		p.campaign.beats.e2 = "skipped_by_block"
		expect(hasPractice()).toBe(true)
	end)

	t.test("jordan: the arc is unscheduled while the campaign runs; Jordan stays a peer", function()
		expect(Content.arcs.jordan_arc.scheduled).toBe(false)
		local p = profile()
		p.activities.fetch = { count = 5 }
		p.activities.agility = { count = 5 }
		expect(EncounterEngine.select(Content, p, "jordan", "dog_park")).toBe(nil)
		expect(EncounterEngine.select(Content, p, "jordan", "agility")).toBe(nil)
		expect(Content.npcs.jordan.role).toBe("peer")
		expect(Content.encounters.jordan_e1_park ~= nil).toBe(true) -- definitions kept
	end)

	t.test("campaign: scenes for the scheduler beats, and walk-up selection", function()
		expect(Content.beatScenes.e1).toBe("park_e1_hello")
		expect(Content.beatScenes.green_riley).toBe("green_riley")
		expect(Content.beatScenes.e2).toBe("park_e2_deal")
		local p = profile()
		expect(EncounterEngine.select(Content, p, "sparkz_pup", "dog_park")).toBe(nil)
		p.campaign.beats.e1 = "eligible"
		expect(EncounterEngine.select(Content, p, "sparkz_pup", "dog_park").id).toBe("park_e1_hello")
		p.campaign.beats.e1 = "resolved"
		p.campaign.beats.e2 = "deferred"
		expect(EncounterEngine.select(Content, p, "sparkz_pup", "dog_park").id).toBe("park_e2_deal")
		expect(EncounterEngine.select(Content, p, "riley", "dog_park").id).toBe("riley_hi")
		p.campaign.beats.green_riley = "eligible"
		expect(EncounterEngine.select(Content, p, "riley", "dog_park").id).toBe("green_riley")
	end)

	t.test("campaign: Cara and Sparkz_Pup are placed; Sparkz is story-only", function()
		for _, id in { "cara", "sparkz_pup" } do
			local npc = Content.npcs[id]
			expect(npc.role).toBe("peer")
			expect(npc.label).toBe("Story character")
			expect(#npc.placements >= 1).toBe(true)
		end
		expect(Content.npcs.sparkz_pup.storyOnly).toBe(true)
		expect(Content.npcs.cara.storyOnly).toBe(nil) -- Cara is always around (and blockable)
	end)

	t.test("campaign: Cara's scenes use bar rule C; Sparkz and Riley scenes have a reflection", function()
		for _, id in { "onb_cara_intro", "cara_talk_1", "cara_fu_e1", "cara_fu_e2", "cara_walk_lee", "cara_practice_menu", "rp_e2_deal" } do
			expect(Content.encounters[id].bar).toBe("C")
		end
		for _, id in { "park_e1_hello", "park_e2_deal", "green_riley", "rp_e2_deal" } do
			local enc = Content.encounters[id]
			expect(enc.nodes[enc.reflect] ~= nil).toBe(true)
		end
	end)

	t.test("campaign: every unsolicited scene has an invitation; the card offers Talk / Later / Skip", function()
		for _, id in { "park_e1_hello", "green_riley", "park_e2_deal", "cara_talk_1" } do
			expect(typeof(Content.encounters[id].invitation.text)).toBe("string")
		end
		local ids = {}
		for _, c in Content.campaign.invitation.choices do
			table.insert(ids, c.id)
		end
		expect(table.concat(ids, ",")).toBe("talk,later,skip")
	end)

	t.test("onboarding: the player is moving within about 30 seconds", function()
		-- Longest path through Lee's welcome, at a child's reading pace of
		-- about three words a second.
		local words = 0
		for _, nodeId in { "welcome", "practice" } do
			local text = Content.encounters.onb_lee_welcome.nodes[nodeId].text
			for _ in string.gmatch(text, "%S+") do
				words += 1
			end
		end
		expect(words <= 90).toBe(true)
		-- Two taps end it, and every ending is friendly.
		local welcome = Content.encounters.onb_lee_welcome
		expect(welcome.nodes.welcome.choices[1].next).toBe("practice")
		for _, c in welcome.nodes.practice.choices do
			expect(c.next).toBe(nil)
		end
		-- The disclosure says what the label is.
		expect(string.find(welcome.nodes.practice.text, "Story character", 1, true) ~= nil).toBe(true)
	end)

	t.test("roleplay: same evidence beat as the scene it replaces", function()
		local rp = Content.encounters.rp_e2_deal
		expect(rp.roleplayFor).toBe("e2")
		expect(rp.beat).toBe(nil) -- never moves the live campaign
		for _, fact in rp.facts do
			expect(Content.facts[fact].beat).toBe("e2")
		end
	end)
end
