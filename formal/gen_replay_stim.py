#!/usr/bin/env python3
"""Emit VHDL stimulus constants for axi_stream_fifo_replay_tb from a BMC trace.

Reads the free DUT inputs (rst, s_tvalid, s_tdata, m_tready) per clock from the
sby counterexample VCD and prints the RST_SEQ/SVALID_SEQ/MREADY_SEQ/SDATA_SEQ
constant lines to paste into formal/replay/axi_stream_fifo_replay_tb.vhd.

Usage: python3 formal/gen_replay_stim.py [trace.vcd] [drain_cycles]
"""
import sys

DEFAULT = "axi_stream_fifo_bmc/engine_0/trace.vcd"
WANT = ["rst", "s_tvalid", "s_tdata", "m_tready"]


def main(path, drain):
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
            if scope == ["axi_stream_fifo_formal"] and p[4] in WANT:
                ids.setdefault(p[4], p[3])

    cur, rows, t = {}, [], None
    for ln in open(path):
        ln = ln.rstrip()
        if ln.startswith("#"):
            if t is not None:
                rows.append((t, dict(cur)))
            t = int(ln[1:])
        elif ln[:1] == "b":
            v, vid = ln[1:].split()
            cur[vid] = v
        elif ln[:1] in "01xz" and not ln.startswith("$"):
            cur[ln[1:]] = ln[0]
    if t is not None:
        rows.append((t, dict(cur)))

    rst, sv, mr, sd = "", "", "", []
    for tt, st in rows:
        if tt % 10:
            continue
        g = lambda n: st.get(ids[n], "0")
        rst += g("rst")[-1]
        sv += g("s_tvalid")[-1]
        mr += g("m_tready")[-1]
        d = g("s_tdata")
        sd.append(int(d, 2) if set(d) <= set("01") else 0)

    rst += "0" * drain
    sv += "0" * drain
    mr += "1" * drain
    sd += [0] * drain

    q = lambda s: '"%s"' % s
    print('  constant RST_SEQ    : std_logic_vector := %s;' % q(rst))
    print('  constant SVALID_SEQ : std_logic_vector := %s;' % q(sv))
    print('  constant MREADY_SEQ : std_logic_vector := %s;' % q(mr))
    body = ", ".join('x"%02X"' % v for v in sd)
    print('  constant SDATA_SEQ  : slv_data_array   := (\n    %s);' % body)


if __name__ == "__main__":
    p = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    d = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    main(p, d)
