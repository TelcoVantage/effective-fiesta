#!/usr/bin/env python3
"""
i3flow.py — codec for Genesys Cloud Architect native flow export files
(.i3InboundEmailFlow, .i3InboundCallFlow, .i3BotFlow, ...).

Reverse-engineered container format (verified round-trip against official
Genesys sample exports):

    file bytes  =  base64( urlencode( JSON ) )

The inner JSON is Architect's *compiled* flow model: UUID-linked actions,
integer trackingIds, and expressions stored as compiled ASTs. It is a compiler
artifact, not a hand-authoring format — for authoring, use the Archy YAML.
This tool lets you decode an export to readable JSON, re-encode an edited JSON
back to an importable file, and verify a round-trip.

Usage:
    i3flow.py decode  <in.i3InboundEmailFlow>  [out.json]
    i3flow.py encode  <in.json>  <out.i3InboundEmailFlow>
    i3flow.py verify  <file.i3InboundEmailFlow>   # decode+re-encode, assert identical
"""
import base64
import json
import sys
import urllib.parse


def decode_bytes(raw: str) -> dict:
    """Decode a native .i3*Flow file body to the flow's JSON model."""
    return json.loads(urllib.parse.unquote(base64.b64decode(raw).decode("utf-8")))


def encode_model(model: dict) -> str:
    """Encode a flow JSON model back into native .i3*Flow file body.

    Genesys uses compact JSON (no spaces) and percent-encodes with the same
    character set as JavaScript encodeURIComponent, then Base64s the result.
    """
    compact = json.dumps(model, separators=(",", ":"), ensure_ascii=False)
    # encodeURIComponent leaves  A-Z a-z 0-9 - _ . ! ~ * ' ( )  unescaped.
    quoted = urllib.parse.quote(compact, safe="!~*'()-_.")
    return base64.b64encode(quoted.encode("utf-8")).decode("ascii")


def _read(path: str) -> str:
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    cmd = argv[1]

    if cmd == "decode":
        model = decode_bytes(_read(argv[2]))
        out = json.dumps(model, indent=2, ensure_ascii=False)
        if len(argv) > 3:
            open(argv[3], "w", encoding="utf-8").write(out + "\n")
            print(f"decoded -> {argv[3]}  (type={model.get('type')}, name={model.get('name')!r})")
        else:
            print(out)
        return 0

    if cmd == "encode":
        model = json.loads(_read(argv[2]))
        open(argv[3], "w", encoding="utf-8").write(encode_model(model))
        print(f"encoded -> {argv[3]}  (type={model.get('type')}, name={model.get('name')!r})")
        return 0

    if cmd == "verify":
        raw = _read(argv[2])
        model = decode_bytes(raw)
        ok = decode_bytes(encode_model(model)) == model
        print("round-trip:", "OK" if ok else "MISMATCH")
        return 0 if ok else 2

    print(f"unknown command: {cmd}\n{__doc__}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
