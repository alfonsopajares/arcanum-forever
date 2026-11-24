"""Run the real addon Lua with a mock WoW UI; no game side effects."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work" / "test-runtime"))
from lupa.lua51 import LuaRuntime
from serving import check_coordination

def create_client():
    client = LuaRuntime()
    client.execute((ROOT / "tests" / "wow-mock.lua").read_text(encoding="utf-8-sig"))
    client.execute('addon = {}; function loadAddon(text) assert(loadstring(text))("Arcanum", addon) end')
    for line in (ROOT / "Arcanum" / "Arcanum.toc").read_text().splitlines():
        if line.startswith("## Version:"):
            client.globals().testAddonVersion = line.split(":", 1)[1].strip()
        if line.strip() and not line.startswith("#"):
            path = ROOT / "Arcanum" / line.replace("\\", "/")
            client.globals().loadAddon(path.read_text(encoding="utf-8-sig"))
    return client


lua = create_client()
lua.execute((ROOT / "tests" / "behavior.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "settings-vending.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "preparation.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "usability.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "ignite.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "group-supplies.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "customization.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "convenience.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "procs.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "drive-by.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "curse-helper.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "incense.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "scrolls.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests" / "native-procs.lua").read_text(encoding="utf-8-sig"))
bindings = ET.parse(ROOT / "Arcanum" / "Bindings.xml").getroot()
assert not any("header" in b.attrib for b in bindings), "Unexpected extra binding header"
for binding in bindings:
    assert binding.attrib.get("category") == "Arcanum", "Binding outside the Arcanum section"
    frame_name = binding.attrib["name"].removeprefix("CLICK ").split(":")[0]
    frame = lua.globals()[frame_name]
    assert frame is not None and "SecureActionButtonTemplate" in frame.template, frame_name
    assert binding.attrib["runOnUp"] == "true", frame_name
    assert lua.globals()["BINDING_NAME_" + binding.attrib["name"]], frame_name
print(f"Validated {len(bindings)} native binding entries against secure buttons and labels.")
check_coordination(create_client)
create_client().execute((ROOT / "tests" / "center-action.lua").read_text(encoding="utf-8-sig"))
