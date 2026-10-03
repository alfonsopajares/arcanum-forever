"""Run the real addon Lua with a mock WoW UI; no game side effects."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work" / "test-runtime"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime()
lua.execute((ROOT / "tests" / "wow-mock.lua").read_text(encoding="utf-8-sig"))
lua.execute('addon = {}; function loadAddon(text) assert(loadstring(text))("Arcanum", addon) end')
for line in (ROOT / "Arcanum" / "Arcanum.toc").read_text().splitlines():
    if line.startswith("## Version:"):
        lua.globals().testAddonVersion = line.split(":", 1)[1].strip()
    if line.strip() and not line.startswith("#"):
        path = ROOT / "Arcanum" / line.replace("\\", "/")
        lua.globals().loadAddon(path.read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "behavior.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "settings-vending.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "preparation.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "usability.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "ignite.lua").read_text(encoding="utf-8-sig"))
bindings = ET.parse(ROOT / "Arcanum" / "Bindings.xml").getroot()
for binding in bindings:
    frame_name = binding.attrib["name"].removeprefix("CLICK ").split(":")[0]
    frame = lua.globals()[frame_name]
    assert frame is not None and "SecureActionButtonTemplate" in frame.template, frame_name
    assert binding.attrib["runOnUp"] == "true", frame_name
    assert lua.globals()["BINDING_NAME_" + binding.attrib["name"]], frame_name
print(f"Validated {len(bindings)} native binding entries against secure buttons and labels.")
