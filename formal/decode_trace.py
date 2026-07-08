#!/usr/bin/env python3
"""Print the axi_stream_fifo BMC counterexample as a beat-by-beat table.

Reads the VCD sby writes on failure and resolves signals by name from the top
`axi_stream_fifo_formal` scope (kept intact via the `keep` attribute in the
wrapper), so it does not depend on VCD id letters that change between runs.

Usage:
    python3 formal/decode_trace.py [path/to/trace.vcd]
Default path: formal/axi_stream_fifo_bmc/engine_0/trace.vcd
"""
import os
import sys

DEFAULT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "axi_stream_fifo_bmc/engine_0/trace.vcd")
WANT = ["s_tvalid", "s_tready", "s_tdata", "wr_expected",
        "m_tvalid", "m_tready", "m_tdata", "rd_expected"]


def main(path):
    scope, ids = [], {}
    for ln in open(path):
        ln = ln.rstrip()
        if ln.startswith("$scope"):
            scope.append(ln.split()[2])
        elif ln.startswith("$upscope"):
            if scope:
                scope.pop()
        elif ln.startswith("$var"):
            p = ln.split()
            name, vid = p[4], p[3]
            # only the top formal scope (where `keep` pins the observables)
            if scope == ["axi_stream_fifo_formal"] and name in WANT:
                ids.setdefault(name, vid)

    missing = [w for w in WANT if w not in ids]
    if missing:
        print("warning: not found at top scope:", missing, file=sys.stderr)

    cur, rows, t = {}, [], None
    for ln in open(path):
        ln = ln.rstrip()
        if ln.startswith("#"):
            if t is not None:
                rows.append((t, dict(cur)))
            t = int(ln[1:])
        elif ln[:1] == "b":
            v, vid = ln[1:].split()
            cur[vid] = str(int(v, 2)) if set(v) <= set("01") else v
        elif ln[:1] in "01xz" and not ln.startswith("$"):
            cur[ln[1:]] = ln[0]
    if t is not None:
        rows.append((t, dict(cur)))

    print("step | " + " ".join("%8s" % c[:8] for c in WANT))
    for t, st in rows:
        if t % 10:                      # 10 time-units per clock; skip half-steps
            continue
        g = lambda c: str(st.get(ids.get(c, ""), "-"))
        note = "OUT beat" if g("m_tvalid") == "1" and g("m_tready") == "1" else ""
        if note and g("m_tdata") != g("rd_expected"):
            note += "  <== VIOLATION got %s want %s" % (g("m_tdata"), g("rd_expected"))
        print("%4d | " % (t // 10) + " ".join("%8s" % g(c) for c in WANT) + "  " + note)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
