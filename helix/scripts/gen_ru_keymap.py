#!/usr/bin/env python3
"""Generate Cyrillic mirrors of Helix's default keymap.

Reads a frozen snapshot of Helix's `helix-term/src/keymap/default.rs`
(see default_keymap_25.07.1.rs) and produces TOML `[keys.normal]` /
`[keys.select]` sections in which every Latin key is duplicated on the
Cyrillic character produced by the *same physical key* in the Russian
("winkeys") layout.

The generated block is written into config.toml between the markers:

    # >>> ru-keymap (generated, do not edit) >>>
    ...
    # <<< ru-keymap (generated, do not edit) <<<

Punctuation that cannot be typed in the Russian layout (`` ` ``, `~`,
`[`, `]`, `'`, `"`, `<`, `>`) is remapped to the Cyrillic character that
sits on the same physical key (`` ` `` -> `ё`, `[` -> `х`, ...). Symbols
whose physical position collides with a different Russian symbol (e.g.
`&` vs `?`) are intentionally dropped and reported.

Usage:  gen_ru_keymap.py [config.toml]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_KEYMAP = HERE / "default_keymap_25.07.1.rs"
DEFAULT_CONFIG = HERE.parent / "config.toml"

BEGIN = "# >>> ru-keymap (generated, do not edit) >>>"
END = "# <<< ru-keymap (generated, do not edit) <<<"

# --- physical-key transliteration: US char -> Russian (winkeys) char --------

_RU_LOWER = {
    "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н", "u": "г",
    "i": "ш", "o": "щ", "p": "з", "[": "х", "]": "ъ",
    "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р", "j": "о",
    "k": "л", "l": "д", ";": "ж", "'": "э",
    "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т", "m": "ь",
    ",": "б", ".": "ю", "/": ".",
}

_RU_PUNCT = {
    "`": "ё", "~": "Ё", "{": "Х", "}": "Ъ", '"': "Э", "<": "Б", ">": "Ю",
    ":": "Ж", "?": ",", "&": "?", "$": ";", "@": '"', "#": "№", "^": ":",
    "!": "!", "%": "%", "*": "*", "(": "(", ")": ")", "-": "-", "_": "_",
    "=": "=", "+": "+", "\\": "\\",
}


def ru_char(ch: str) -> str | None:
    """Return the Russian char on the same physical key, or None if N/A."""
    if ch in _RU_LOWER:
        return _RU_LOWER[ch]
    if ch.isascii() and ch.isalpha():
        low = _RU_LOWER.get(ch.lower())
        return low.upper() if low else None
    return _RU_PUNCT.get(ch)


# --- parser for default.rs `keymap!({ ... })` blocks ------------------------

MODIFIERS = {"C", "A", "S", "Meta", "Cmd", "Win", "Super"}


class Command:
    __slots__ = ("name",)

    def __init__(self, name: str):
        self.name = name

    def __repr__(self):
        return f"cmd({self.name})"

    def __eq__(self, other):
        return isinstance(other, Command) and other.name == self.name


class Sequence:
    """A key bound to a list of commands, e.g. ["move_char_right", "insert_mode"]."""

    __slots__ = ("commands",)

    def __init__(self, commands):
        self.commands = tuple(commands)

    def __repr__(self):
        return f"seq({', '.join(self.commands)})"

    def __eq__(self, other):
        return isinstance(other, Sequence) and other.commands == self.commands


class Node:
    __slots__ = ("name", "sticky", "children")

    def __init__(self, name: str = "", sticky: bool = False):
        self.name = name
        self.sticky = sticky
        self.children: dict[str, Command | Sequence | "Node"] = {}


class _Parser:
    def __init__(self, text: str):
        self.s = text
        self.i = 0

    def ws(self):
        while self.i < len(self.s):
            c = self.s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif self.s.startswith("//", self.i):
                nl = self.s.find("\n", self.i)
                self.i = len(self.s) if nl < 0 else nl + 1
            else:
                break

    def string(self) -> str:
        assert self.s[self.i] == '"', self.s[self.i : self.i + 10]
        self.i += 1
        out = []
        while self.s[self.i] != '"':
            c = self.s[self.i]
            if c == "\\":
                self.i += 1
                e = self.s[self.i]
                out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(e, e))
            else:
                out.append(c)
            self.i += 1
        self.i += 1
        return "".join(out)

    def ident(self) -> str:
        start = self.i
        while self.i < len(self.s) and (self.s[self.i].isalnum() or self.s[self.i] == "_"):
            self.i += 1
        return self.s[start : self.i]

    def entries(self) -> Node:
        """Parse '{ "Name" [sticky=true] <entry>, ... }'."""
        self.ws()
        assert self.s[self.i] == "{"
        self.i += 1
        self.ws()
        node = Node(name=self.string())
        self.ws()
        if self.s.startswith("sticky=true", self.i):
            node.sticky = True
            self.i += len("sticky=true")
            self.ws()
        while True:
            self.ws()
            if self.s[self.i] == "}":
                self.i += 1
                break
            keys = [self.string()]
            self.ws()
            while self.s[self.i] == "|":
                self.i += 1
                self.ws()
                keys.append(self.string())
                self.ws()
            assert self.s.startswith("=>", self.i)
            self.i += 2
            self.ws()
            if self.s[self.i] == "{":
                value: Command | Node = self.entries()
            else:
                value = Command(self.ident())
            for k in keys:
                node.children[k] = value
            self.ws()
            if self.s[self.i] == ",":
                self.i += 1
        return node

    def keymaps(self) -> dict[str, Node]:
        """Parse every `keymap!({...})` block, keyed by mode name."""
        result: dict[str, Node] = {}
        for m in re.finditer(r"keymap!\(\s*\{", self.s):
            self.i = m.end() - 1  # position of '{'
            node = self.entries()
            mode = node.name.split()[0].lower()
            result[mode] = node
        return result


def is_modified(key: str) -> bool:
    if "-" not in key:
        return False
    return any(part in MODIFIERS for part in key.split("-")[:-1])


def merge(base: Node, over: Node) -> Node:
    """Deep-merge like Helix's KeyTrieNode::merge (over wins)."""
    out = Node(base.name, base.sticky)
    for k, v in base.children.items():
        out.children[k] = v
    for k, v in over.children.items():
        if isinstance(out.children.get(k), Node) and isinstance(v, Node):
            out.children[k] = merge(out.children[k], v)  # type: ignore[arg-type]
        else:
            out.children[k] = v
    return out


def mirror(node: Node, warn: list[str], path: str = "") -> Node:
    """Return a Node holding Cyrillic mirrors of `node`'s children."""
    out = Node()
    native = node.children
    for key, value in native.items():
        if is_modified(key):
            continue
        if len(key) > 1:
            # Named key (space, esc, home, ...): layout-independent. If it is a
            # prefix, recurse so its Cyrillic children still get bound.
            if isinstance(value, Node):
                sub = mirror(value, warn, f"{path}.{key}")
                if sub.children:
                    out.children[key] = sub
            continue
        target = ru_char(key)
        if target is None or target == key:
            continue
        if target in native:
            existing = native[target]
            if isinstance(existing, Command) and isinstance(value, Command) and existing == value:
                continue  # redundant
            warn.append(
                f"{path or '<root>'}: skip {key!r} -> {target!r} "
                f"(collides with existing {target!r})"
            )
            continue
        if isinstance(value, Node):
            out.children[target] = mirror(value, warn, f"{path}.{key}")
        else:
            out.children[target] = value
    return out


# --- manual overrides -------------------------------------------------------
#
# Applied to the mirrored map (after `mirror`), keyed by mode. A key is either
# a Latin key (to override a Helix default) or a Cyrillic mirror (to override
# the generated binding). Both `a` and `ф` are set so the behaviour is the same
# regardless of the active keyboard layout.
#
# Why: Helix's `a` (`append_mode`) deliberately keeps a one-character selection
# and sets `restore_cursor`; unlike `i`/`A` it therefore leaves text visibly
# selected while typing. Binding `a` to `move_char_right` + `insert_mode` (the
# equivalent of `li`) collapses the selection to a point first, so it behaves
# like `i`/`A`. See helix-editor/helix#9036 and #9443.
#
# Values may be nested dicts to add bindings under an existing prefix (e.g.
# `space`) without dropping the rest of that submap -- see `apply_overrides`.
OVERRIDES: dict[str, dict[str, object]] = {
    "normal": {
        "a": Sequence(["move_char_right", "insert_mode"]),
        "ф": Sequence(["move_char_right", "insert_mode"]),
        # Git blame of the current line, printed to the statusline. Lives here
        # (inside the generated block) because a second `[keys.normal]` table
        # would be invalid TOML; `B`/`И` cover both keyboard layouts.
        "space": {
            "B": Command(':echo %sh{git blame -L %{cursor_line},+1 %{buffer_name}}'),
            "И": Command(':echo %sh{git blame -L %{cursor_line},+1 %{buffer_name}}'),
        },
    },
}


def apply_overrides(node: Node, overrides: dict[str, object]) -> None:
    for key, value in overrides.items():
        if isinstance(value, dict):
            child = node.children.get(key)
            if not isinstance(child, Node):
                child = Node(key)
                node.children[key] = child
            apply_overrides(child, value)
        else:
            node.children[key] = value  # type: ignore[assignment]


# --- TOML rendering ---------------------------------------------------------

_BARE = re.compile(r"^[A-Za-z0-9_-]+$")


def render_key(key: str) -> str:
    if _BARE.match(key):
        return key
    return '"' + key.replace("\\", "\\\\").replace('"', '\\"') + '"'


def toml_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render_value(value: Command | Sequence) -> str:
    if isinstance(value, Command):
        return toml_string(value.name)
    return "[" + ", ".join(toml_string(c) for c in value.commands) + "]"


def render_table(prefix: list[str], node: Node, lines: list[str]):
    single: list[tuple[str, Command | Sequence | Node]] = []
    for k, v in sorted(node.children.items()):
        single.append((k, v))
    header = ".".join(prefix)
    lines.append(f"[{header}]")
    for k, v in single:
        if isinstance(v, (Command, Sequence)):
            lines.append(f"{render_key(k)} = {render_value(v)}")
    lines.append("")
    for k, v in single:
        if isinstance(v, Node):
            render_table(prefix + [render_key(k)], v, lines)


def render_mode(mode: str, root: Node) -> str:
    lines: list[str] = []
    render_table([f"keys.{mode}"], root, lines)
    return "\n".join(lines).rstrip() + "\n"


def build() -> str:
    text = DEFAULT_KEYMAP.read_text(encoding="utf-8")
    maps = _Parser(text).keymaps()
    normal = maps["normal"]
    select = merge(normal, maps["select"])

    warn: list[str] = []
    parts = [
        BEGIN,
        "# Generated by scripts/gen_ru_keymap.py -- do not edit by hand.",
        "# Cyrillic mirrors of Helix's default keymap (physical-key layout).",
        "",
    ]
    for mode, node in (("normal", normal), ("select", select)):
        mirrored = mirror(node, warn, mode)
        apply_overrides(mirrored, OVERRIDES.get(mode, {}))
        parts.append(render_mode(mode, mirrored))
    parts.append(END)
    parts.append("")

    if warn:
        print("warning:", file=sys.stderr)
        for w in warn:
            print("  " + w, file=sys.stderr)
    return "\n".join(parts)


def write_config(config_path: Path, block: str):
    text = config_path.read_text(encoding="utf-8")
    if BEGIN in text and END in text:
        pre = text[: text.index(BEGIN)]
        post = text[text.index(END) + len(END) :]
        new = pre.rstrip() + "\n\n" + block.rstrip() + "\n" + post.lstrip("\n")
    else:
        new = text.rstrip() + "\n\n" + block
    config_path.write_text(new, encoding="utf-8")


def main():
    config_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CONFIG
    block = build()
    if len(sys.argv) > 2 and sys.argv[2] == "--stdout":
        sys.stdout.write(block)
        return
    write_config(config_path, block)
    print(f"updated {config_path}")


if __name__ == "__main__":
    main()
