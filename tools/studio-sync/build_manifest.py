#!/usr/bin/env python3
"""Builds manifest.json (a Rojo-like tree of the repo's Luau) for the Studio sync snippet."""
import json, os, sys

repo = sys.argv[1]
out = sys.argv[2]

ROOTS = [
    (["ReplicatedStorage"], "Shared", "src/shared"),
    (["ServerScriptService"], "Server", "src/server"),
    (["ServerStorage"], "Tests", "tests"),
    (["StarterPlayer", "StarterPlayerScripts"], "Client", "src/client"),
]

def file_node(path, fname):
    src = open(path, encoding="utf-8").read()
    for suffix, cls in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if fname.endswith(suffix):
            return {"name": fname[: -len(suffix)], "className": cls, "source": src, "children": []}
    return None

def dir_node(path, name):
    node = {"name": name, "className": "Folder", "children": []}
    for init, cls in (("init.server.luau", "Script"), ("init.client.luau", "LocalScript"), ("init.luau", "ModuleScript")):
        p = os.path.join(path, init)
        if os.path.exists(p):
            node["className"] = cls
            node["source"] = open(p, encoding="utf-8").read()
    for entry in sorted(os.listdir(path)):
        if entry.startswith("init.") or entry.startswith("."):
            continue
        full = os.path.join(path, entry)
        child = dir_node(full, entry) if os.path.isdir(full) else file_node(full, entry)
        if child:
            node["children"].append(child)
    return node

manifest = [{"parent": parent, "node": dir_node(os.path.join(repo, rel), name)} for parent, name, rel in ROOTS]
json.dump(manifest, open(out, "w"))
print("ok", os.path.getsize(out))
