"""One handler per event name, and a handler for every event the mod sends. (The idea is EXACG's, PR #11.)

  python -I tools/netlab/eventcheck.py [folder of Scripts]

All handlers live in one table, so setting a name twice quietly drops the first: revive.lua's gauge once took coop.lua's "G",
and a guest's kill never reached the host. Only a check can notice that. Setting a name again is fine in one case: a file keeps
the old handler in a local first and calls it from the new one, as moves.lua does. A kept handler that's never called
still loses the first, so that's refused too.
"""
import glob
import os
import re
import sys

ASSIGN = re.compile(r"^[ \t]*(?:coop\.)?handlers\.(\w+)[ \t]*=(?!=)", re.M)
KEEP = re.compile(r"^[ \t]*local[ \t]+(\w+)[ \t]*=[ \t]*(?:coop\.)?handlers\.(\w+)[ \t]*$", re.M)
SEND = re.compile(r"\bsend(?:Event|To)\(\s*(?:[\w.]+\s*,\s*)?\"([^\"]+)\"")
LOADED = re.compile(r'dofile\(SCRIPT_DIR \.\. "(\w+\.lua)"\)')


def line_of(text, at):
    return text.count("\n", 0, at) + 1


def function_body(text, match):
    """From the assignment to the end at its own indent."""
    start = text.rfind("\n", 0, match.start()) + 1
    indent = re.match(r"[ \t]*", text[start:]).group()
    end = text.find("\n" + indent + "end", match.end())
    return text[match.end():end if end >= 0 else len(text)]


def check(files):
    """files: (name, text) in the order the game loads them. Returns (problems, handlers, sent names)."""
    first, sent, problems = {}, {}, []
    for name, text in files:
        for match in ASSIGN.finditer(text):
            key = match.group(1)
            where = "%s:%d" % (name, line_of(text, match.start()))
            if key not in first:
                first[key] = where
                continue
            body = function_body(text, match)
            kept = [k.group(1) for k in KEEP.finditer(text, 0, match.start()) if k.group(2) == key]
            if not any(re.search(r"\b" + variable + r"\(", body) for variable in kept):
                problems.append("%s: set at %s, and again at %s without calling the first" % (key, first[key], where))
        for match in SEND.finditer(text):
            sent.setdefault(match.group(1), "%s:%d" % (name, line_of(text, match.start())))
    for key, where in sorted(sent.items()):
        if key not in first:
            problems.append("%s: sent at %s, and nobody handles it" % (key, where))
    return problems, first, sent


def proves_itself():
    """A check that can't fail proves nothing: each of these must come out as it says."""
    wrapped = 'local old = coop.handlers.M\ncoop.handlers.M = function(rest)\n    return old(rest)\nend\n'
    forgot = 'local old = coop.handlers.M\ncoop.handlers.M = function(rest)\n    return 1\nend\n'
    cases = [
        ("one handler, one sender", [("a", 'handlers.K = function() end\nsendEvent("K", x)\n')], 0),
        ("a wrapper that calls the first", [("a", "handlers.M = function() end\n"), ("b", wrapped)], 0),
        ("two files on one name", [("a", "handlers.K = function() end\n"), ("b", "coop.handlers.K = function() end\n")], 1),
        ("one file setting a name twice", [("a", "handlers.K = function() end\nhandlers.K = function() end\n")], 1),
        ("keeping the first but not calling it", [("a", "handlers.M = function() end\n"), ("b", forgot)], 1),
        ("sending what nobody handles", [("a", 'coop.sendEvent("Q2", 1)\n')], 1),
        ("sending to one guest what nobody handles", [("a", 'sendTo(from, "Q3", 1)\n')], 1),
    ]
    good = True
    for what, files, expected in cases:
        if len(check(files)[0]) != expected:
            print("the check itself is wrong on: " + what)
            good = False
    return good


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "mod", "PBZCoop", "Scripts")
    if not proves_itself():
        return 1
    texts = {}
    for path in glob.glob(os.path.join(folder, "*.lua")):
        texts[os.path.basename(path)] = open(path, encoding="utf-8").read().replace("\r\n", "\n")
    order = LOADED.findall(texts["main.lua"])
    files = [(name, texts[name]) for name in order if name in texts]
    files += [(name, text) for name, text in sorted(texts.items()) if name not in order]
    problems, first, sent = check(files)
    for line in problems:
        print("  " + line)
    print("%d handlers, %d names sent, %d problems" % (len(first), len(sent), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
