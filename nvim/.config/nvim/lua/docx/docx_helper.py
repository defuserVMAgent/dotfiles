#!/usr/bin/env python3
"""Surgical-edit helper for the docx-edit nvim plugin.

Subcommands:
  extract <docx> <tmpdir>           Extract marker-format text to stdout.
  repack  <docx> <tmpdir> <buffer>  Repack the buffer back into the docx.
"""

import json
import os
import re
import shutil
import sys
import zipfile
from collections import defaultdict
from copy import deepcopy

try:
    from docx import Document
    from docx.oxml import OxmlElement
except ImportError:
    sys.stderr.write(
        "python-docx is not installed.\n"
        "Install with:  python3 -m pip install --user python-docx\n"
    )
    sys.exit(2)

from lxml import etree


W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
XML_NS = "http://www.w3.org/XML/1998/namespace"
NSMAP = {"w": W_NS}

TAB_TOKEN = "⟦→⟧"
BREAK_TOKEN = "⟦↵⟧"
MARKER_RE = re.compile(r"⟦([0-9]+)(?::(field|obj))?⟧")


def wq(local):
    return f"{{{W_NS}}}{local}"


def xmlq(local):
    return f"{{{XML_NS}}}{local}"


def iter_paragraphs(body):
    return list(body.iter(wq("p")))


def runs_in_paragraph(p):
    return list(p.iter(wq("r")))


def canon_rPr(rPr):
    if rPr is None:
        return b""
    return etree.tostring(rPr, method="c14n")


def has_child(elem, locals_):
    for local in locals_:
        if elem.find(wq(local)) is not None:
            return True
    return False


def classify_run(r):
    has_fld_marker = has_child(r, ["fldChar", "instrText"])
    has_obj = has_child(r, ["drawing", "pict", "sym", "object"])
    if has_obj and not has_fld_marker:
        return "obj"
    if has_fld_marker:
        return "field-marker"
    return "text"


def is_field_end(r):
    for fc in r.iter(wq("fldChar")):
        if fc.get(wq("fldCharType")) == "end":
            return True
    return False


def is_field_begin(r):
    for fc in r.iter(wq("fldChar")):
        if fc.get(wq("fldCharType")) == "begin":
            return True
    return False


def run_visible_text(r):
    parts = []
    for child in r:
        ln = etree.QName(child).localname
        if ln == "t":
            parts.append(child.text or "")
        elif ln == "tab":
            parts.append(TAB_TOKEN)
        elif ln in ("br", "cr"):
            parts.append(BREAK_TOKEN)
    return "".join(parts)


def has_header_or_footer(docx_path):
    with zipfile.ZipFile(docx_path) as z:
        for name in z.namelist():
            if name.startswith("word/header") or name.startswith("word/footer"):
                return True
    return False


def extract(src_docx, tmpdir):
    os.makedirs(tmpdir, exist_ok=True)
    shutil.copy(src_docx, os.path.join(tmpdir, "original.docx"))

    doc = Document(src_docx)
    body = doc.element.body
    paragraphs = iter_paragraphs(body)

    groups = []
    paragraph_lines = []

    for p_idx, p in enumerate(paragraphs):
        runs = runs_in_paragraph(p)
        line_parts = []

        if not runs:
            group_idx = len(groups) + 1
            groups.append({
                "index": group_idx,
                "paragraph": p_idx,
                "runs": [],
                "kind": "empty-para",
                "text": "",
            })
            line_parts.append(f"⟦{group_idx}⟧")
            paragraph_lines.append("".join(line_parts))
            continue

        in_field = False
        i = 0
        while i < len(runs):
            r = runs[i]
            kind = classify_run(r)

            if kind == "field-marker" or in_field:
                field_run_indices = []
                field_text_parts = []
                while i < len(runs):
                    rr = runs[i]
                    rk = classify_run(rr)
                    if not in_field and rk != "field-marker":
                        break
                    field_run_indices.append(i)
                    field_text_parts.append(run_visible_text(rr))
                    ended = is_field_end(rr)
                    if is_field_begin(rr):
                        in_field = True
                    i += 1
                    if ended:
                        in_field = False
                        break

                combined = "".join(field_text_parts)
                group_idx = len(groups) + 1
                groups.append({
                    "index": group_idx,
                    "paragraph": p_idx,
                    "runs": field_run_indices,
                    "kind": "field",
                    "text": combined,
                })
                line_parts.append(f"⟦{group_idx}:field⟧{combined}")
            elif kind == "obj":
                group_idx = len(groups) + 1
                groups.append({
                    "index": group_idx,
                    "paragraph": p_idx,
                    "runs": [i],
                    "kind": "obj",
                    "text": "",
                })
                line_parts.append(f"⟦{group_idx}:obj⟧")
                i += 1
            else:
                rPr = r.find(wq("rPr"))
                canon = canon_rPr(rPr)
                merged_indices = [i]
                merged_text = [run_visible_text(r)]
                j = i + 1
                while j < len(runs):
                    nr = runs[j]
                    if classify_run(nr) != "text":
                        break
                    if canon_rPr(nr.find(wq("rPr"))) != canon:
                        break
                    merged_indices.append(j)
                    merged_text.append(run_visible_text(nr))
                    j += 1

                combined = "".join(merged_text)
                group_idx = len(groups) + 1
                groups.append({
                    "index": group_idx,
                    "paragraph": p_idx,
                    "runs": merged_indices,
                    "kind": "text",
                    "text": combined,
                })
                line_parts.append(f"⟦{group_idx}⟧{combined}")
                i = j

        paragraph_lines.append("".join(line_parts))

    sidecar = {
        "groups": groups,
        "paragraph_count": len(paragraphs),
    }
    with open(os.path.join(tmpdir, "runs.json"), "w", encoding="utf-8") as f:
        json.dump(sidecar, f, ensure_ascii=False, indent=2)

    field_count = sum(1 for g in groups if g["kind"] == "field")
    obj_count = sum(1 for g in groups if g["kind"] == "obj")
    meta = {
        "field_count": field_count,
        "obj_count": obj_count,
        "has_header_footer": has_header_or_footer(src_docx),
    }
    with open(os.path.join(tmpdir, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False)

    output = "\n\n".join(paragraph_lines)
    sys.stdout.write(output)
    if output and not output.endswith("\n"):
        sys.stdout.write("\n")


def parse_marker_line(line, line_num):
    stripped = line.lstrip()
    leading = len(line) - len(stripped)
    matches = list(MARKER_RE.finditer(stripped))
    if not matches:
        raise ValueError(
            f"line {line_num}: no markers found in non-blank line: {line!r}"
        )
    if matches[0].start() != 0:
        raise ValueError(
            f"line {line_num}: text before first marker is not allowed: "
            f"{stripped[:matches[0].start()]!r}"
        )
    markers = []
    for k, m in enumerate(matches):
        idx = int(m.group(1))
        kind = m.group(2)
        if k + 1 < len(matches):
            text = stripped[m.end():matches[k + 1].start()]
        else:
            text = stripped[m.end():]
        markers.append((idx, kind, text))
    return markers


def parse_buffer(buffer_text):
    buffer_text = buffer_text.replace("\r\n", "\n").replace("\r", "\n")
    paragraphs = []
    for ln, line in enumerate(buffer_text.split("\n"), start=1):
        if not line.strip():
            continue
        paragraphs.append(parse_marker_line(line, ln))
    return paragraphs


def set_run_text(r, text):
    rPr = r.find(wq("rPr"))
    for child in list(r):
        if child is not rPr:
            r.remove(child)

    tokens = re.split(r"(⟦→⟧|⟦↵⟧)", text)
    for tok in tokens:
        if tok == TAB_TOKEN:
            r.append(OxmlElement("w:tab"))
        elif tok == BREAK_TOKEN:
            r.append(OxmlElement("w:br"))
        elif tok:
            t = OxmlElement("w:t")
            t.text = tok
            t.set(xmlq("space"), "preserve")
            r.append(t)


def in_place_update(p_elem, markers, groups_by_index, p_runs, src_p_idx):
    run_to_group = {}
    for g in groups_by_index.values():
        if g["paragraph"] != src_p_idx:
            continue
        for ri in g["runs"]:
            run_to_group[ri] = g

    buffer_groups = {idx: text for (idx, _, text) in markers}

    runs_to_remove = []
    for run_idx, r_elem in enumerate(p_runs):
        g = run_to_group.get(run_idx)
        if g is None:
            continue
        if g["index"] not in buffer_groups:
            runs_to_remove.append(r_elem)
            continue
        if g["kind"] == "text":
            if run_idx == g["runs"][0]:
                set_run_text(r_elem, buffer_groups[g["index"]])
            else:
                runs_to_remove.append(r_elem)

    for r in runs_to_remove:
        parent = r.getparent()
        if parent is not None:
            parent.remove(r)


def fill_with_clones(p_elem, markers, groups_by_index, p_runs):
    for (idx, kind, text) in markers:
        g = groups_by_index[idx]
        if g["kind"] == "text":
            first = p_runs[g["runs"][0]]
            new_r = deepcopy(first)
            set_run_text(new_r, text)
            p_elem.append(new_r)
        elif g["kind"] == "obj":
            first = p_runs[g["runs"][0]]
            new_r = deepcopy(first)
            p_elem.append(new_r)
        elif g["kind"] == "field":
            for ri in g["runs"]:
                orig = p_runs[ri]
                new_r = deepcopy(orig)
                p_elem.append(new_r)


def split_paragraph(src_p, bps, groups_by_index, p_runs):
    pPr = src_p.find(wq("pPr"))

    for child in list(src_p):
        if child is not pPr:
            src_p.remove(child)

    fill_with_clones(src_p, bps[0], groups_by_index, p_runs)

    prev = src_p
    for markers in bps[1:]:
        new_p = OxmlElement("w:p")
        prev.addnext(new_p)
        if pPr is not None:
            new_p.insert(0, deepcopy(pPr))
        fill_with_clones(new_p, markers, groups_by_index, p_runs)
        prev = new_p


def repack(src_docx, tmpdir, buffer_file):
    original_docx = os.path.join(tmpdir, "original.docx")

    with open(os.path.join(tmpdir, "runs.json"), "r", encoding="utf-8") as f:
        sidecar = json.load(f)

    with open(buffer_file, "r", encoding="utf-8") as f:
        buffer_text = f.read()

    buffer_paragraphs = parse_buffer(buffer_text)
    groups_by_index = {g["index"]: g for g in sidecar["groups"]}

    for bp_idx, markers in enumerate(buffer_paragraphs, start=1):
        for (idx, kind, text) in markers:
            if idx not in groups_by_index:
                raise ValueError(
                    f"unknown marker ⟦{idx}⟧ in buffer paragraph {bp_idx}"
                )
            g = groups_by_index[idx]
            expected = "" if g["kind"] in ("text", "empty-para") else g["kind"]
            got = kind or ""
            if expected != got:
                exp_disp = (":" + expected) if expected else "(none)"
                got_disp = (":" + got) if got else "(none)"
                raise ValueError(
                    f"marker ⟦{idx}⟧ in buffer paragraph {bp_idx}: "
                    f"expected sigil {exp_disp}, got {got_disp}"
                )
            if g["kind"] == "field" and text != g["text"]:
                raise ValueError(
                    f"field marker ⟦{idx}:field⟧ text was modified "
                    f"(fields are read-only). expected {g['text']!r}, got {text!r}"
                )
            if g["kind"] == "obj" and text != "":
                raise ValueError(
                    f"object marker ⟦{idx}:obj⟧ in buffer paragraph "
                    f"{bp_idx} cannot have text after it (got {text!r})"
                )
            if g["kind"] == "empty-para" and text != "":
                raise ValueError(
                    f"empty-paragraph marker ⟦{idx}⟧ in buffer paragraph "
                    f"{bp_idx} cannot have text after it (got {text!r})"
                )

    source_to_bps = defaultdict(list)
    for bp_idx, markers in enumerate(buffer_paragraphs, start=1):
        src_paragraphs = {groups_by_index[m[0]]["paragraph"] for m in markers}
        if len(src_paragraphs) > 1:
            raise ValueError(
                f"buffer paragraph {bp_idx} has markers from multiple source "
                f"paragraphs ({sorted(src_paragraphs)}); merging paragraphs is "
                f"not supported"
            )
        src_p = next(iter(src_paragraphs))
        source_to_bps[src_p].append(markers)

    for bp_idx, markers in enumerate(buffer_paragraphs, start=1):
        keys = []
        for (idx, _, _) in markers:
            g = groups_by_index[idx]
            keys.append(g["runs"][0] if g["runs"] else -1)
        if keys != sorted(keys):
            raise ValueError(
                f"buffer paragraph {bp_idx}: markers are out of original "
                f"order; reordering runs within a paragraph is not supported"
            )

    doc = Document(original_docx)
    body = doc.element.body
    paragraphs_xml = iter_paragraphs(body)
    paragraph_runs = [runs_in_paragraph(p) for p in paragraphs_xml]

    if len(paragraphs_xml) != sidecar.get("paragraph_count", len(paragraphs_xml)):
        raise ValueError(
            "original docx paragraph count mismatch; sidecar is stale"
        )

    paragraphs_to_remove = []
    for src_p_idx, src_p in enumerate(paragraphs_xml):
        bps = source_to_bps.get(src_p_idx, [])
        if not bps:
            paragraphs_to_remove.append(src_p)
            continue
        if len(bps) == 1:
            in_place_update(
                src_p, bps[0], groups_by_index,
                paragraph_runs[src_p_idx], src_p_idx,
            )
        else:
            split_paragraph(
                src_p, bps, groups_by_index, paragraph_runs[src_p_idx]
            )

    for p in paragraphs_to_remove:
        parent = p.getparent()
        if parent is not None:
            parent.remove(p)

    for hl in list(body.iter(wq("hyperlink"))):
        if next(hl.iter(wq("r")), None) is None:
            parent = hl.getparent()
            if parent is not None:
                parent.remove(hl)

    tmp_path = src_docx + ".tmp"
    try:
        doc.save(tmp_path)
        os.replace(tmp_path, src_docx)
    except Exception:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass
        raise


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("usage: docx_helper.py {extract|repack} ...\n")
        sys.exit(2)
    cmd = sys.argv[1]
    try:
        if cmd == "extract":
            if len(sys.argv) != 4:
                sys.stderr.write("usage: docx_helper.py extract <docx> <tmpdir>\n")
                sys.exit(2)
            extract(sys.argv[2], sys.argv[3])
        elif cmd == "repack":
            if len(sys.argv) != 5:
                sys.stderr.write(
                    "usage: docx_helper.py repack <docx> <tmpdir> <buffer-file>\n"
                )
                sys.exit(2)
            repack(sys.argv[2], sys.argv[3], sys.argv[4])
        else:
            sys.stderr.write(f"unknown command: {cmd}\n")
            sys.exit(2)
    except ValueError as e:
        sys.stderr.write(f"{e}\n")
        sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"docx-helper internal error: {e.__class__.__name__}: {e}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
