# Converts the upstream Oniguruma 6.9.8 tests (test/test_*.c) into JSON cases.
import re, json, sys, os
SRC = sys.argv[1]
OUT = sys.argv[2]

hdr = open(os.path.join(SRC, '../src/oniguruma.h')).read()
consts = {}
def ev(expr):
    e = expr.replace('1U', '1').replace('0U', '0')
    e = re.sub(r'\b([A-Z_][A-Z0-9_]+)\b', lambda m: str(consts[m.group(1)]) if m.group(1) in consts else m.group(0), e)
    return eval(e)
for m in re.finditer(r'^#define\s+(ONIG\w+)\s+(.+?)\s*(/\*.*)?$', hdr, re.M):
    try:
        consts[m.group(1)] = ev(m.group(2))
    except Exception:
        pass
consts['OIA'] = consts['ONIG_OPTION_IGNORECASE'] | consts['ONIG_OPTION_IGNORECASE_IS_ASCII']

def c_string(lit):
    # lit: content between quotes
    out = bytearray()
    i = 0
    while i < len(lit):
        c = lit[i]
        if c == '\\':
            i += 1
            c = lit[i]
            if c == 'x':
                j = i + 1
                h = ''
                while j < len(lit) and lit[j] in '0123456789abcdefABCDEF':
                    h += lit[j]; j += 1
                out.append(int(h, 16) & 0xff); i = j; continue
            elif c == 'u' or c == 'U':
                n = 4 if c == 'u' else 8
                cp = int(lit[i+1:i+1+n], 16)
                out += chr(cp).encode('utf-8'); i += 1 + n; continue
            elif c in '01234567':
                j = i
                o = ''
                while j < len(lit) and len(o) < 3 and lit[j] in '01234567':
                    o += lit[j]; j += 1
                out.append(int(o, 8) & 0xff); i = j; continue
            else:
                m = {'n': 10, 't': 9, 'r': 13, 'f': 12, 'v': 11, 'a': 7, 'b': 8, 'e': 27, '\\': 92, '"': 34, "'": 39, '?': 63}
                out.append(m[c]); i += 1; continue
        else:
            out.append(ord(c) & 0xff); i += 1
    return bytes(out)

def parse_args(argstr):
    # split the macro arguments, joining adjacent string literals
    args = []
    i = 0
    cur = None
    while i < len(argstr):
        c = argstr[i]
        if c == '"':
            j = i + 1
            while argstr[j] != '"':
                if argstr[j] == '\\': j += 2
                else: j += 1
            b = c_string(argstr[i+1:j])
            if isinstance(cur, bytes): cur += b
            else: cur = b
            i = j + 1
        elif c == ',':
            args.append(cur); cur = None; i += 1
        elif c in ' \t\n':
            i += 1
        else:
            j = i
            while j < len(argstr) and argstr[j] not in ',':
                j += 1
            tok = argstr[i:j].strip()
            cur = ev(tok) if not re.match(r'^-?\d+$', tok) else int(tok)
            i = j
    args.append(cur)
    return args

class CallMatch:
    def __init__(self, name, args): self.g = (name, args)
    def group(self, i): return self.g[i - 1]

class CallRe:
    def match(self, l):
        m = re.match(r'^\s*(x2|x3|n|e)\(', l)
        if not m: return None
        i = m.end()
        depth = 1
        start = i
        while i < len(l):
            c = l[i]
            if c == '"':
                i += 1
                while l[i] != '"':
                    i += 2 if l[i] == '\\' else 1
            elif c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    return CallMatch(m.group(1), l[start:i])
            i += 1
        return None

CALL_RE = CallRe()

def cut_nul(b):
    k = b.find(b'\0')
    return b if k < 0 else b[:k]

def make_case(kind, args, syntax, back, with_opt, line):
    opt = 0
    if with_opt:
        opt = args[0]; args = args[1:]
    p, s = cut_nul(args[0]), cut_nul(args[1])
    c = {'k': kind, 'syn': syntax, 'opt': opt, 'back': back, 'p': p.hex(), 's': s.hex(), 'line': line}
    if kind == 'x2': c.update(f=args[2], t=args[3], m=0)
    elif kind == 'x3': c.update(f=args[2], t=args[3], m=args[4])
    elif kind == 'e': c.update(err=args[2])
    return c

def join_lines(lines):
    out = []
    i = 0
    while i < len(lines):
        l = lines[i]
        no = i + 1
        if re.match(r'^\s*(x2|x3|n|e)\(', l):
            while CALL_RE.match(l) is None:
                i += 1
                l = l + ' ' + lines[i].strip()
        out.append((no, l))
        i += 1
    return out

def convert_simple(fname, syntax, back, with_opt):
    cases = []
    lines = open(os.path.join(SRC, fname), encoding='latin-1').read().split('\n')
    in_main = False
    buf = ''
    for no, l in join_lines(lines):
        if 'main(int argc' in l: in_main = True
        if not in_main: continue
        m = CALL_RE.match(l)
        if m:
            cases.append(make_case(m.group(1), parse_args(m.group(2)), syntax, back, with_opt, no))
        elif re.match(r'^\s*(x2|x3|n|e)\(', l):
            raise Exception('unparsed line %d: %s' % (no, l))
    return cases

def convert_syntax(fname):
    text = open(os.path.join(SRC, fname), encoding='latin-1').read()
    lines = text.split('\n')
    funcs = {}
    joined = join_lines(lines)
    cur = None
    main_lines = []
    for no, l in joined:
        fm = re.match(r'^static int (test_\w+)\(\)', l)
        if fm: cur = fm.group(1); funcs[cur] = []; continue
        if 'main(int argc' in l: cur = 'main'; continue
        if cur is None: continue
        if cur == 'main': main_lines.append((no, l))
        else: funcs[cur].append((no, l))
    cases = []
    syntax = None
    def run(body):
        nonlocal syntax
        for no, l in body:
            sm = re.match(r'^\s*Syntax = ONIG_SYNTAX_(\w+);', l)
            if sm: syntax = sm.group(1); continue
            tm = re.match(r'^\s*(test_\w+)\(\);', l)
            if tm: run(funcs[tm.group(1)]); continue
            m = CALL_RE.match(l)
            if m: cases.append(make_case(m.group(1), parse_args(m.group(2)), syntax, False, False, no))
            elif re.match(r'^\s*(x2|x3|n|e)\(', l): raise Exception('unparsed %d %s' % (no, l))
    run(main_lines)
    return cases

all_sets = {
    'utf8': convert_simple('test_utf8.c', 'DEFAULT', False, False),
    'back': convert_simple('test_back.c', 'DEFAULT', True, False),
    'options': convert_simple('test_options.c', 'DEFAULT', False, True),
    'syntax': convert_syntax('test_syntax.c'),
}
for k, v in all_sets.items():
    json.dump(v, open(os.path.join(OUT, 'upstream-' + k + '.json'), 'w'))
    print(k, len(v))
