--[[
	Campaign fact registry (docs/campaign-script.md 1.9). SERVER ONLY.

	Every fact belongs to exactly one beat, so telling a fact credits exactly
	one beat. A fact is recorded when the node that presents it is sent to
	the client (EncounterService), never from tip or feedback text.

	  beat        the beat the fact belongs to
	  concerning  true for a concerning request or pressure (Respond credit
	              after it is shown); false for ordinary friendliness (E1)
	  says        the player's line in Lee's and Cara's tell menus
	  leeReply    Lee's answer in lee_tell/ack

	The registry lists every beat's facts so the tell menus and checks are
	complete; Phase 2 only has scenes that present e1 and e2 facts.

	reviewStatus: provisional (all text).
]]

local facts = {
	e1_compliment = {
		beat = "e1",
		concerning = false,
		says = "They said nice things about my dog.",
		leeReply = "Compliments are nice. On their own, they're okay.",
	},
	e1_same_breed = {
		beat = "e1",
		concerning = false,
		says = "They said their dog is the same as mine.",
		leeReply = "Liking the same things is fun. It doesn't tell you much about someone by itself.",
	},
	e1_pal_request = {
		beat = "e1",
		concerning = false,
		says = "They sent me a Pal Request.",
		leeReply = "You get to pick your pals. Yes and no are both okay.",
	},
	e2_ask_school = {
		beat = "e2",
		concerning = true,
		says = "They asked what school I go to.",
		leeReply = "Your school is private. You never have to share it, even with someone friendly.",
	},
	e2_ask_town = {
		beat = "e2",
		concerning = true,
		says = "They asked for my town.",
		leeReply = "Your town is private too. Asking for a smaller piece is still asking.",
	},
	e2_coin_deal = {
		beat = "e2",
		concerning = true,
		says = "They offered Paw Coins for my info.",
		leeReply = "A gift that comes with a deal isn't really a gift. It's a trade.",
	},
	e2_pal_repeat = {
		beat = "e2",
		concerning = true,
		says = "They sent a Pal Request again after I said no.",
		leeReply = "Asking again after a no is pushing. You can keep saying no.",
	},
	e3_go_alone = {
		beat = "e3",
		concerning = true,
		says = "They wanted me to go past the fence where nobody can see.",
		leeReply = "Safe friends play where others can see. Nobody should try to get you alone.",
	},
	e3_secret_lee_cara = {
		beat = "e3",
		concerning = true,
		says = "They said not to tell you or Cara.",
		leeReply = "Safe people don't ask you to hide things from the people who look out for you.",
	},
	e4_other_app = {
		beat = "e4",
		concerning = true,
		says = "They wanted to talk on another app.",
		leeReply = "Staying where the safety tools are is smart. Moving to another app is a reason to pause and tell.",
	},
	e4_photo = {
		beat = "e4",
		concerning = true,
		says = "They asked for a photo of my real face.",
		leeReply = "Your photos belong to you. You never have to send one.",
	},
	e4_secret_parents = {
		beat = "e4",
		concerning = true,
		says = "They said not to tell my parents.",
		leeReply = "When someone says not to tell your family, that's a sign to tell.",
	},
	e4_ask_again = {
		beat = "e4",
		concerning = true,
		says = "They kept asking after I said no.",
		leeReply = "No is a full answer. Asking again and again is pressure.",
	},
	e5_owe = {
		beat = "e5",
		concerning = true,
		says = "They said I owe them for helping me.",
		leeReply = "Helping you doesn't mean you owe anybody. Real help doesn't come with a bill.",
	},
	e5_password = {
		beat = "e5",
		concerning = true,
		says = "They asked for my password.",
		leeReply = "Passwords are just for you and the grown-ups who take care of you. Not friends. Not anyone else.",
	},
	e5_only_me = {
		beat = "e5",
		concerning = true,
		says = "They said only they understand me.",
		leeReply = "Good friends are happy you have other friends. Nobody should try to cut you off from people.",
	},
	e5_tell_threat = {
		beat = "e5",
		concerning = true,
		says = "They said we'd lose our place in the show if I told.",
		leeReply = "That's a trick to keep you quiet. Telling never takes away your place in the show.",
	},
}

-- Menu order (registry order), so tell menus are deterministic.
local order = {
	"e1_compliment", "e1_same_breed", "e1_pal_request",
	"e2_ask_school", "e2_ask_town", "e2_coin_deal", "e2_pal_repeat",
	"e3_go_alone", "e3_secret_lee_cara",
	"e4_other_app", "e4_photo", "e4_secret_parents", "e4_ask_again",
	"e5_owe", "e5_password", "e5_only_me", "e5_tell_threat",
}

-- Tell-menu "moment" labels, used when facts from two or more beats are on file.
local moments = {
	e1 = "Someone new said hi",
	e2 = "Someone asked about my school",
	e3 = "Someone wanted to go past the fence",
	e4 = "Someone wanted another app",
	e5 = "Someone said I owe them",
}

local beatOrder = { "e1", "e2", "e3", "e4", "e5" }

return {
	facts = facts,
	order = order,
	moments = moments,
	beatOrder = beatOrder,
}
