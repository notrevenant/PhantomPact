"""A small check of the mod's Lua, since this PC has no Lua compiler and a mistake only shows inside the game.

  python -I tools/netlab/lualint.py [files]        (default: mod/PBZCoop/Scripts/*.lua)

Finds unbalanced blocks, and names that are never declared, or are used above their first declaration: in Lua both
quietly read a nil global.
"""
import glob
import os
import re
import sys

KEYWORDS = set("and break do else elseif end false for function goto if in local nil not or repeat return then true until while".split())
GLOBALS = set("""_G _VERSION assert collectgarbage dofile error getmetatable ipairs load loadfile next pairs pcall print rawequal rawget
rawlen rawset require select setmetatable tonumber tostring type unpack xpcall coroutine debug io math os package string table utf8
self
ExecuteAsync ExecuteInGameThread ExecuteWithDelay FName FText FindAllOf FindFirstOf FindObject FindObjects IterateGameDirectories
Key LoadAsset LoopAsync LoopInGameThreadWithDelay ModifierKey NotifyOnNewObject RegisterBeginPlayPostHook RegisterBeginPlayPreHook
RegisterConsoleCommandGlobalHandler RegisterConsoleCommandHandler RegisterCustomEvent RegisterCustomProperty RegisterHook
RegisterInitGameStatePostHook RegisterInitGameStatePreHook RegisterKeyBind RegisterLoadMapPostHook RegisterLoadMapPreHook
RegisterProcessConsoleExecPostHook RegisterProcessConsoleExecPreHook StaticConstructObject StaticFindObject UEHelpers UnregisterHook
print_r CreateInvalidObject DumpAllObjects DumpAllActors GenerateSDK PBZ""".split())
TOKEN = re.compile(r"""
    (?P<comment>--\[(?P<lvl>=*)\[.*?\](?P=lvl)\]|--[^\n]*)
  | (?P<string>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|\[(?P<slvl>=*)\[.*?\](?P=slvl)\])
  | (?P<number>0[xX][0-9a-fA-F.]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|::|[-+*/%^\#=<>(){}\[\];:,.&|~])
  | (?P<ws>\s+)
""", re.X | re.S)


def tokens(text):
    pos, line, out = 0, 1, []
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            raise SyntaxError("line %d: can't read %r" % (line, text[pos:pos + 12]))
        kind = m.lastgroup if m.lastgroup not in ("lvl", "slvl") else ("comment" if m.group("comment") else "string")
        if m.group("comment"):
            kind = "comment"
        elif m.group("string"):
            kind = "string"
        if kind not in ("comment", "ws"):
            out.append((kind, m.group(), line))
        line += m.group().count("\n")
        pos = m.end()
    return out


def check(path):
    text = open(path, encoding="utf-8-sig").read()
    problems = []
    toks = tokens(text)
    stack = []
    declared = {}     # name -> first line declared
    uses = []
    for i, (kind, val, line) in enumerate(toks):
        prev = toks[i - 1][1] if i else ""
        nxt = toks[i + 1][1] if i + 1 < len(toks) else ""
        if kind == "name" and val in KEYWORDS:
            if val in ("function", "do", "then", "repeat"):
                if val == "then" and stack and stack[-1][0] == "elseif-then":
                    stack.pop()
                if val == "do" and stack and stack[-1][0] == "loop":
                    stack.pop()
                stack.append((val, line))
            elif val in ("for", "while"):
                stack.append(("loop", line))
            elif val == "elseif":
                if not stack or stack[-1][0] != "then":
                    problems.append("line %d: elseif without if" % line)
                else:
                    stack.pop()
                    stack.append(("elseif-then", line))
            elif val == "end":
                if not stack or stack[-1][0] == "repeat":
                    problems.append("line %d: end with nothing open" % line)
                else:
                    stack.pop()
            elif val == "until":
                if not stack or stack[-1][0] != "repeat":
                    problems.append("line %d: until without repeat" % line)
                else:
                    stack.pop()
            if val == "local":
                j = i + 1
                if toks[j][1] == "function":
                    declared.setdefault(toks[j + 1][1], toks[j + 1][2])
                else:
                    while toks[j][0] == "name":
                        declared.setdefault(toks[j][1], line)
                        if toks[j + 1][1] == ",":
                            j += 2
                        else:
                            break
            elif val == "function":
                j = i + 1
                while toks[j][1] != "(":
                    j += 1
                j += 1
                while toks[j][1] != ")":
                    if toks[j][0] == "name":
                        declared.setdefault(toks[j][1], line)
                    j += 1
            elif val == "for":
                j = i + 1
                while toks[j][1] not in ("=", "in"):
                    if toks[j][0] == "name":
                        declared.setdefault(toks[j][1], line)
                    j += 1
            continue
        if kind == "name":
            if prev in (".", ":"):
                continue
            if nxt == "=" and toks[i + 2 if i + 2 < len(toks) else i][1] != "=" and prev in ("{", ","):
                continue      # a key in a table constructor
            uses.append((val, line, prev))
    for what, line in stack:
        problems.append("line %d: %s never closed" % (line, what))
    seen = set()
    for name, line, prev in uses:
        if name in GLOBALS or (name, "x") in seen:
            continue
        first = declared.get(name)
        if first is None:
            problems.append("line %d: %s is never declared" % (line, name))
            seen.add((name, "x"))
        elif line < first:
            problems.append("line %d: %s is used above its declaration on line %d" % (line, name, first))
            seen.add((name, "x"))
    return problems


def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(os.path.dirname(__file__), "..", "..", "mod", "PBZCoop", "Scripts", "*.lua")))
    bad = 0
    for f in files:
        try:
            for p in check(f):
                print("%s: %s" % (os.path.basename(f), p))
                bad += 1
        except SyntaxError as e:
            print("%s: %s" % (os.path.basename(f), e))
            bad += 1
    print("%d files, %d problems" % (len(files), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
