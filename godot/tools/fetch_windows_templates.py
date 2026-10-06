"""Fetch just Windows x64 entries from the official Godot template ZIP.

HTTP ranges avoid downloading the 1.2 GB multi-platform archive. Files stay
inside the ignored build/templates folder; no global installation is changed.
"""
import io
import pathlib
import urllib.request
import zipfile

URL = "https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz"
DESTINATION = pathlib.Path(__file__).resolve().parents[1] / "build" / "templates"


class RemoteZip(io.RawIOBase):
    def __init__(self):
        with urllib.request.urlopen(urllib.request.Request(URL, method="HEAD"), timeout=30) as response:
            self.url = response.url
            self.length = int(response.headers["Content-Length"])
        self.position = 0

    def seekable(self):
        return True

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else (self.position if whence == 1 else self.length) + offset
        return self.position

    def tell(self):
        return self.position

    def read(self, size=-1):
        size = self.length - self.position if size < 0 else min(size, self.length - self.position)
        if size <= 0:
            return b""
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.position}-{self.position + size - 1}"})
        with urllib.request.urlopen(request, timeout=60) as response:
            if response.status != 206:
                raise RuntimeError("Server ignored byte range; refusing full archive download")
            data = response.read(size)
        if len(data) != size:
            raise IOError("Incomplete byte range")
        self.position += len(data)
        return data


if __name__ == "__main__":
    DESTINATION.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(RemoteZip()) as archive:
        for name in ["windows_release_x86_64.exe", "windows_debug_x86_64.exe"]:
            info = archive.getinfo("templates/" + name)
            content = archive.read(info)  # zipfile validates each entry's CRC.
            (DESTINATION / name).write_bytes(content)
            print(f"Verified ZIP entry: {name} ({len(content)} bytes)", flush=True)
