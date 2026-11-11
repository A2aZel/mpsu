#!/usr/bin/env python3
"""Validate binary CYBERcobra listings and write one 32-bit HEX word per line."""
import argparse
from pathlib import Path
import re


MAX_WORDS = 128


def convert(src_path, dst_path):
    source = Path(src_path)
    destination = Path(dst_path)
    if source.resolve() == destination.resolve():
        raise ValueError("Input and output must be different files")
    words = []
    for lineno, raw in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("//", 1)[0].strip()
        if not line:
            continue
        if re.fullmatch(r"[01 \t]+", line) is None:
            raise ValueError(f"Line {lineno}: only 0, 1, spaces and tabs are allowed before //")
        bits = line.replace(" ", "").replace("\t", "")
        if len(bits) != 32:
            raise ValueError(f"Line {lineno}: got {len(bits)} bits, expected 32")
        words.append(f"{int(bits, 2):08x}")
        if len(words) > MAX_WORDS:
            raise ValueError(f"Program exceeds {MAX_WORDS} words in the configured ROM")
    if not words:
        raise ValueError("Program contains no instructions")
    # Parsing finishes before opening the destination, preserving it on input errors.
    destination.write_text("\n".join(words) + "\n", encoding="ascii", newline="\n")
    return words


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    try:
        words = convert(args.source, args.destination)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Error: {error}\n")
    print(f"OK: {len(words)} instructions -> {args.destination}")


if __name__ == "__main__":
    main()
