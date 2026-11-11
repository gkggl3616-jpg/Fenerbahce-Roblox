#!/usr/bin/env python3
"""default.project.json + src/ -> FenerKariyer.rbxlx (Roblox Studio'da çift tıkla açılır).
Rojo kurmadan çalışır:  python3 tools/build_rbxlx.py"""
import json, os, sys
from xml.sax.saxutils import escape

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TOKENS = {"Technology": {"Future": 4, "ShadowMap": 3}, "ScreenOrientation": {"LandscapeSensor": 2}}
ref = 0


def item(cls, name, props="", children=""):
    global ref
    ref += 1
    return f'<Item class="{cls}" referent="RBX{ref}"><Properties><string name="Name">{escape(name)}</string>{props}</Properties>{children}</Item>\n'


def script(cls, name, path, children=""):
    src = open(path, encoding="utf-8").read().replace("]]>", "]]]]><![CDATA[>")
    return item(cls, name, f'<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>', children)


def from_path(name, path):
    if os.path.isfile(path):
        base = os.path.basename(path)
        for suffix, cls in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
            if base.endswith(suffix):
                return script(cls, name or base[: -len(suffix)], path)
        return ""
    kids, init = "", None
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if entry in ("init.luau", "init.server.luau", "init.client.luau"):
            init = full
            continue
        kids += from_path(None, full)
    name = name or os.path.basename(path)
    if init:
        cls = "Script" if init.endswith(".server.luau") else "LocalScript" if init.endswith(".client.luau") else "ModuleScript"
        return script(cls, name, init, kids)
    return item("Folder", name, "", kids)


def from_node(name, node):
    if "$path" in node:
        path = os.path.join(ROOT, node["$path"])
        if "$className" in node and os.path.isdir(path):
            kids = "".join(from_path(None, os.path.join(path, e)) for e in sorted(os.listdir(path)))
            return item(node["$className"], name, "", kids)
        return from_path(name, path)
    props = ""
    for key, value in node.get("$properties", {}).items():
        if isinstance(value, bool):
            props += f'<bool name="{key}">{"true" if value else "false"}</bool>'
        elif key in TOKENS:
            props += f'<token name="{key}">{TOKENS[key][value]}</token>'
        else:
            sys.exit(f"Bilinmeyen özellik: {key}")
    kids = "".join(from_node(k, v) for k, v in node.items() if not k.startswith("$"))
    return item(node["$className"], name, props, kids)


project = json.load(open(os.path.join(ROOT, "default.project.json"), encoding="utf-8"))
body = "".join(from_node(k, v) for k, v in project["tree"].items() if not k.startswith("$"))
out = os.path.join(ROOT, project["name"] + ".rbxlx")
with open(out, "w", encoding="utf-8") as f:
    f.write('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n' + body + "</roblox>\n")
print(out, os.path.getsize(out), "bayt,", ref, "nesne")
