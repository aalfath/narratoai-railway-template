"""Build-time helper: download the pinned NarratoAI release and subtitle font, check their sha256."""
import hashlib, os, sys, tarfile, urllib.request

def fetch(url, dest, sha):
    data = urllib.request.urlopen(url, timeout=300).read()
    got = hashlib.sha256(data).hexdigest()
    if got != sha:
        sys.exit(f"{url}: sha256 {got} does not match the pinned {sha}")
    with open(dest, "wb") as f:
        f.write(data)

e = os.environ
commit = e["NARRATOAI_COMMIT"]
fetch(f"https://github.com/linyqh/NarratoAI/archive/{commit}.tar.gz", "/tmp/src.tgz", e["NARRATOAI_SHA256"])
fetch(e["FONT_URL"], "/tmp/SourceHanSansCN-Regular.otf", e["FONT_SHA256"])
with tarfile.open("/tmp/src.tgz") as t:
    t.extractall("/tmp", filter="data")
os.rename(f"/tmp/NarratoAI-{commit}", "/src")
os.remove("/tmp/src.tgz")
