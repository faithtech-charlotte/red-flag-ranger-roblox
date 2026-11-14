-- Paste into the Roblox Studio MCP execute_luau tool (Edit mode, not Play).
-- Rebuilds Shared / Server / Tests / Client from tools/studio-sync/manifest.json
-- served at http://localhost:34999 (see README in this folder).
local HttpService = game:GetService("HttpService")
local manifest = HttpService:JSONDecode(HttpService:GetAsync("http://localhost:34999/manifest.json", true))
local count = 0
local function build(node, parent)
	local inst = Instance.new(node.className)
	inst.Name = node.name
	if node.source then inst.Source = node.source end
	for _, child in node.children do build(child, inst) end
	count += 1
	inst.Parent = parent
end
for _, entry in manifest do
	local parent = game
	for _, name in entry.parent do parent = parent:FindFirstChild(name) or game:GetService(name) end
	local old = parent:FindFirstChild(entry.node.name)
	if old then old:Destroy() end
	build(entry.node, parent)
end
-- A World left over from an edit-mode preview would stop WorldBuilder from regenerating.
if workspace:FindFirstChild("World") then workspace.World:Destroy() end
return "synced " .. count .. "\n" .. require(game.ServerStorage.Tests)()
