#!/usr/bin/env python3
"""Конвертер программ CYBERcobra: текст с комментариями (//) и двоичным
кодом -> .mem-файл с 8-значными hex по слову на строку.
Использование: python cyberconvert.py <вход.txt> <выход.mem>
"""
import sys


def convert(src_path, dst_path):
    words = []
    with open(src_path, "r", encoding="utf-8") as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.split("//", 1)[0]
            bits = "".join(ch for ch in line if ch in "01")
            if not bits:
                continue
            if len(bits) != 32:
                raise ValueError(
                    f"Строка {lineno}: получено {len(bits)} бит, ожидалось 32"
                )
            words.append(f"{int(bits, 2):08x}")
    with open(dst_path, "w", encoding="utf-8") as f:
        f.write("\n".join(words) + "\n")
    return words


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "program_var19.txt"
    dst = sys.argv[2] if len(sys.argv) > 2 else "program.mem"
    out = convert(src, dst)
    print(f"OK: {len(out)} инструкций -> {dst}")
    for i, w in enumerate(out):
        print(f"{i:2d}: {w}")
