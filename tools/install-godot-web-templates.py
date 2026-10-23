"""Install only the official Web templates from Godot's large template archive."""
import argparse
import io
import pathlib
import urllib.request
import zipfile


class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        request = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(request, timeout=90) as response:
            self.url = response.url
            self.length = int(response.headers["Content-Length"])
        self.position = 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position

    def read(self, size=-1):
        if size < 0:
            size = self.length - self.position
        size = min(size, self.length - self.position)
        if not size:
            return b""
        start = self.position
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={start}-{start + size - 1}"})
        with urllib.request.urlopen(request, timeout=180) as response:
            if response.status != 206:
                raise RuntimeError("Official download did not support HTTP ranges; refusing a partial template")
            data = response.read()
        if len(data) != size:
            raise RuntimeError("Incomplete template download")
        self.position += len(data)
        return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", required=True, type=pathlib.Path)
    args = parser.parse_args()
    version = "4.7.2.stable"
    url = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
    with zipfile.ZipFile(RemoteZip(url)) as archive:
        version_entry = next(name for name in archive.namelist() if name.endswith("/version.txt"))
        if archive.read(version_entry).decode().strip() != version:
            raise RuntimeError("Unexpected Godot template version")
        args.destination.mkdir(parents=True, exist_ok=True)
        for filename in ("web_nothreads_release.zip", "web_nothreads_debug.zip"):
            entry = next(name for name in archive.namelist() if name.endswith("/" + filename))
            # ZipFile verifies each member's CRC before it is written.
            payload = archive.read(entry)
            with zipfile.ZipFile(io.BytesIO(payload)) as template:
                bad = template.testzip()
                if bad:
                    raise RuntimeError("Corrupt Web template: " + bad)
            target = args.destination / filename
            target.write_bytes(payload)
            print(f"Installed {target.name}: {len(payload):,} bytes", flush=True)
        (args.destination / "version.txt").write_text(version + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
