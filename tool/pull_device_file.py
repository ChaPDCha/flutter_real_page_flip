"""Read a device file through small verified ADB shell replies.

Fallback for USB links that reset during bulk `adb pull`. No device settings
are changed. Interrupted transfers resume from a sidecar .usb-part file.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--adb", default=shutil.which("adb"))
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("remote")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if not args.adb:
        parser.error("adb was not found")

    def shell(command):
        return subprocess.run(
            [args.adb, "-s", args.serial, "shell", "-n", command],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            timeout=15,
            check=False,
        )

    remote = shlex.quote(args.remote)
    info = shell(f"stat -c %s {remote}; sha256sum {remote}")
    if info.returncode:
        raise RuntimeError(info.stderr.decode(errors="replace"))
    lines = info.stdout.decode().splitlines()
    total, expected_hash = int(lines[0]), lines[1].split()[0].lower()
    if len(expected_hash) != 64:
        raise RuntimeError("Device did not return a SHA-256 hash")
    output = args.output.resolve()
    if output.exists():
        if hashlib.sha256(output.read_bytes()).hexdigest() == expected_hash:
            print(json.dumps({"file": str(output), "bytes": total,
                              "sha256": expected_hash, "verified": True}))
            return
        if not args.overwrite:
            raise FileExistsError(f"Refusing to overwrite {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    part = output.with_name(output.name + ".usb-part")
    metadata = output.with_name(output.name + ".usb-part.json")
    signature = {"serial": args.serial, "remote": args.remote,
                 "bytes": total, "sha256": expected_hash, "block": 192}
    resume = (part.exists() and metadata.exists()
              and json.loads(metadata.read_text()) == signature)
    offset = part.stat().st_size if resume else 0
    if offset > total or (offset != total and offset % 192):
        offset = 0
    started = time.monotonic()
    last_report = started
    retries = 0
    with part.open("r+b" if resume else "w+b") as target:
        target.truncate(offset)
        target.seek(offset)
        metadata.write_text(json.dumps(signature), encoding="utf-8")
        while offset < total:
            block = offset // 192
            expected_bytes = min(192, total - offset)
            error = ""
            for attempt in range(6):
                try:
                    reply = shell(
                        f"dd if={remote} bs=192 skip={block} count=1 "
                        "2>/dev/null | base64"
                    )
                    data = base64.b64decode(b"".join(reply.stdout.split()),
                                            validate=True)
                    if reply.returncode == 0 and len(data) == expected_bytes:
                        break
                    error = reply.stderr.decode(errors="replace")
                except (subprocess.TimeoutExpired, ValueError) as failure:
                    error = str(failure)
                retries += 1
                time.sleep(0.3)
            else:
                raise RuntimeError(f"Block {block} failed; resume preserved: {error}")
            target.write(data)
            target.flush()
            offset += len(data)
            now = time.monotonic()
            if now - last_report >= 5:
                print(f"USB {offset}/{total} bytes; retries={retries}", flush=True)
                last_report = now
    actual_hash = hashlib.sha256(part.read_bytes()).hexdigest()
    if actual_hash != expected_hash:
        raise RuntimeError("SHA-256 mismatch: output not published; partial retained")
    os.replace(part, output)
    metadata.unlink()
    print(json.dumps({"file": str(output), "bytes": total,
                      "sha256": actual_hash, "verified": True,
                      "seconds": round(time.monotonic() - started, 2),
                      "retries": retries}), flush=True)


if __name__ == "__main__":
    main()
