# Studio sync without Rojo

Rojo isn't installed on this machine. To push the repo's Luau into an open
Studio session through the Roblox Studio MCP server:

```bash
cd tools/studio-sync
python3 build_manifest.py ../.. manifest.json
python3 -m http.server 34999 --bind 127.0.0.1   # leave running
```

Then stop Play mode and run `sync.luau` with the MCP `execute_luau` tool
(Edit datamodel). It rebuilds the four Rojo-mapped trees and runs the tests.
`manifest.json` is generated; don't commit it.
