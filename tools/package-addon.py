"""Build and verify a clean Arcanum Forever install ZIP using only stdlib."""
from pathlib import Path
import hashlib
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Arcanum"


def build():
    toc = (SOURCE / "Arcanum.toc").read_text(encoding="utf-8-sig")
    version = re.search(r"^## Version:\s*([\w.-]+)\s*$", toc, re.MULTILINE).group(1)
    assert "## Interface: 16001" in toc, "Unexpected target interface"
    assert "## X-License: MIT" in toc, "Missing license metadata"
    names = ["Arcanum.toc", "Bindings.xml", "LICENSE",
             "Media/Orb.tga", "Media/CircleMask.tga", "Media/Ring.tga"]
    names += [line.strip().replace("\\", "/") for line in toc.splitlines()
              if line.strip() and not line.startswith("#")]
    assert len(names) == len(set(names)), "Duplicate manifest entry"
    files = {}
    for name in names:
        file = SOURCE / name
        assert file.is_file() and not file.is_symlink(), f"Missing/unsafe file: {name}"
        assert file.resolve().is_relative_to(SOURCE.resolve()), f"Out-of-source file: {name}"
        files[f"Arcanum/{name}"] = file.read_bytes()
    assert files["Arcanum/LICENSE"] == (ROOT / "LICENSE").read_bytes(), "License copies differ"
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    readme = re.sub(r"^!\[Arcanum Forever logo\].*\n", "", readme, flags=re.MULTILINE)
    assert "C:\\Users" not in readme and "C:\\Projects" not in readme, "Personal paths in README"
    files["Arcanum/README.md"] = readme.encode("utf-8")
    destination = ROOT / "dist"
    destination.mkdir(exist_ok=True)
    archive = destination / f"Arcanum-Forever-{version}.zip"
    # Stable ordering and timestamps give identical archives for identical inputs.
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as package:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2026, 10, 3, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            package.writestr(info, data)
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None, "Archive CRC failure"
        assert set(package.namelist()) == set(files), "Unexpected archive contents"
        for name, data in files.items():
            assert package.read(name) == data, f"Content mismatch: {name}"
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
    print(f"Built {archive.name}: {len(files)} verified files, {archive.stat().st_size:,} bytes")
    print(f"SHA-256: {digest}")


if __name__ == "__main__":
    build()
