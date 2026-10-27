#!/usr/bin/env python3
"""Validate Personalliste ALL exports and create one staging-ready TSV.

The report's Druckdatum is written to both lastinsertupdate and filedate. The
raw attachments are read in place; only the requested final output is written.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import os
import re
import sys
import tempfile
import unicodedata
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path


DB_COLUMNS = (
    "pers_nr",
    "name_vorname",
    "zeitarbeitsfirma",
    "oe_der_person",
    "schicht",
    "info",
    "beginn_besch",
    "ende_besch",
    "eg",
    "geschlecht",
    "taetigkeit",
    "team",
    "betriebsrat",
    "einstellungsdatum",
    "taetigkeit2",
    "funktion",
    "gebdatum",
    "lastinsertupdate",
    "filedate",
)


def normalize_label(value: str) -> str:
    folded = unicodedata.normalize("NFKD", value).casefold()
    folded = "".join(ch for ch in folded if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]+", " ", folded).strip()


# The mapping uses normalized header text, then reads that column by its
# original index. Empty separator columns in the report therefore stay intact.
HEADER_TO_COLUMN = {
    "persnr": "pers_nr",
    "name vorname": "name_vorname",
    "03 zeitarbeitsfirma": "zeitarbeitsfirma",
    "zeitarbeitsfirma": "zeitarbeitsfirma",
    "oe der person": "oe_der_person",
    "10 schicht": "schicht",
    "schicht": "schicht",
    "info 2": "info",
    "info": "info",
    "beginn beschaftigung": "beginn_besch",
    "ende beschaftigung": "ende_besch",
    "eg": "eg",
    "entgeltgruppe": "eg",
    "01 geschlecht": "geschlecht",
    "geschlecht": "geschlecht",
    "tatigkeit": "taetigkeit",
    "13 team": "team",
    "team": "team",
    "12 betriebsrat": "betriebsrat",
    "betriebsrat": "betriebsrat",
    "eintrittsdatum": "einstellungsdatum",
    "14 tatigkeit": "taetigkeit2",
    "16 funktion": "funktion",
    "geb datum": "gebdatum",
}

REQUIRED_HEADERS = {
    "pers_nr",
    "name_vorname",
    "zeitarbeitsfirma",
    "oe_der_person",
    "schicht",
    "info",
    "beginn_besch",
    "ende_besch",
    "geschlecht",
    "taetigkeit",
    "team",
    "betriebsrat",
    "einstellungsdatum",
    "taetigkeit2",
    "funktion",
    "gebdatum",
}

DATE_COLUMNS = {
    "beginn_besch",
    "ende_besch",
    "einstellungsdatum",
    "gebdatum",
}


class ReportError(ValueError):
    pass


@dataclass(frozen=True)
class Snapshot:
    path: Path
    printed_at: datetime
    sha256: str
    row_count: int


@dataclass(frozen=True)
class ParsedReport:
    printed_at: datetime
    rows: list[list[str]]
    header_index: int
    footer_index: int
    footer_count: int
    header_indices: dict[str, int]
    delimiter: str


def decode_report_bytes(raw: bytes, path: Path) -> str:
    for encoding in ("utf-8-sig", "utf-16", "cp1252"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise ReportError(f"{path.name}: unsupported text encoding")


def decode_report(path: Path) -> str:
    return decode_report_bytes(path.read_bytes(), path)


def find_header(rows: list[list[str]]) -> tuple[int, dict[str, int]] | None:
    for row_index, row in enumerate(rows[:40]):
        found: dict[str, int] = {}
        for column_index, label in enumerate(row):
            mapped = HEADER_TO_COLUMN.get(normalize_label(label))
            if mapped is None:
                continue
            if mapped in found:
                raise ReportError(
                    f"header row {row_index + 1}: multiple columns map to {mapped}"
                )
            found[mapped] = column_index
        if REQUIRED_HEADERS.issubset(found):
            return row_index, found
    return None


def load_rows_and_header(
    path: Path, text: str | None = None
) -> tuple[list[list[str]], int, dict[str, int], str]:
    if text is None:
        text = decode_report(path)
    delimiters: list[str] = []
    try:
        sniffed = csv.Sniffer().sniff(text[:65536], delimiters=";,\t").delimiter
        delimiters.append(sniffed)
    except csv.Error:
        pass
    for delimiter in (";", "\t", ","):
        if delimiter not in delimiters:
            delimiters.append(delimiter)

    candidates = []
    for delimiter in delimiters:
        rows = list(csv.reader(io.StringIO(text, newline=""), delimiter=delimiter))
        match = find_header(rows)
        if match is None:
            continue
        header_index, header_indices = match
        # Prefer the format that recognizes the most report fields and the
        # earliest complete header. This rejects comma-splitting a name label.
        score = (len(header_indices), -header_index, -abs(len(rows[header_index]) - 20))
        candidates.append((score, rows, header_index, header_indices, delimiter))

    if not candidates:
        raise ReportError(f"{path.name}: couldn't find the complete report header")
    candidates.sort(key=lambda item: item[0], reverse=True)
    _, rows, header_index, header_indices, delimiter = candidates[0]
    return rows, header_index, header_indices, delimiter


def parse_printed_at(rows: list[list[str]], header_index: int, path: Path) -> datetime:
    found: list[datetime] = []
    for row in rows[:header_index]:
        for index, cell in enumerate(row):
            if normalize_label(cell).startswith("druckdatum"):
                value = next((part.strip() for part in row[index + 1 :] if part.strip()), "")
                if not value:
                    raise ReportError(f"{path.name}: Druckdatum has no value")
                found.append(parse_datetime(value, path))
                break
    if not found:
        raise ReportError(f"{path.name}: Druckdatum wasn't found before the header")
    if any(value != found[0] for value in found[1:]):
        raise ReportError(f"{path.name}: conflicting Druckdatum values")
    return found[0]


def parse_datetime(value: str, path: Path, field: str = "Druckdatum") -> datetime:
    value = value.strip()
    formats = (
        "%d.%m.%Y %H:%M:%S",
        "%d.%m.%Y %H:%M",
        "%d.%m.%Y",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d",
    )
    for fmt in formats:
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    raise ReportError(f"{path.name}: {field} has an unsupported date format")


def parse_footer_count(rows: list[list[str]], header_index: int, path: Path) -> tuple[int, int]:
    for row_index in range(header_index + 1, len(rows)):
        row = rows[row_index]
        for index, cell in enumerate(row):
            if normalize_label(cell).startswith("anzahl personen"):
                value = next((part.strip() for part in row[index + 1 :] if part.strip()), "")
                digits = re.sub(r"[^0-9]", "", value)
                if not digits:
                    raise ReportError(f"{path.name}: footer person count has no numeric value")
                return row_index, int(digits)
    raise ReportError(f"{path.name}: 'Anzahl Personen' footer wasn't found")


def parse_person_number(value: str, path: Path, row_number: int) -> int:
    value = value.strip()
    if not re.fullmatch(r"\d+", value):
        raise ReportError(f"{path.name}: invalid PersNr. on CSV row {row_number}")
    return int(value)


def parse_date(value: str, column: str, path: Path, row_number: int) -> str | None:
    value = value.strip()
    if not value:
        return None
    if column == "ende_besch" and normalize_label(value) in {"unbegrenzt", "unlimited"}:
        return "9999-12-31"

    parsed = parse_datetime(value, path, column)
    return parsed.date().isoformat()


def structural_data_row_count(report: ParsedReport, path: Path) -> int:
    width = len(report.rows[report.header_index])
    row_count = 0
    for row_index in range(report.header_index + 1, report.footer_index):
        row = report.rows[row_index]
        if not any(cell.strip() for cell in row) or find_header([row]) is not None:
            continue
        if len(row) > width and any(cell.strip() for cell in row[width:]):
            raise ReportError(f"{path.name}: extra CSV fields on row {row_index + 1}")
        row_count += 1
    if row_count != report.footer_count:
        raise ReportError(
            f"{path.name}: footer says {report.footer_count} people, "
            f"but {row_count} structurally valid data rows were parsed"
        )
    return row_count


def normalized_data_rows(report: ParsedReport, path: Path) -> list[list[str | int | None]]:
    width = len(report.rows[report.header_index])
    person_index = report.header_indices["pers_nr"]
    seen: set[int] = set()
    normalized_rows: list[list[str | int | None]] = []

    for row_index in range(report.header_index + 1, report.footer_index):
        row = report.rows[row_index]
        if not any(cell.strip() for cell in row):
            continue
        if find_header([row]) is not None:
            continue  # Some report versions repeat headings on page breaks.
        if len(row) > width:
            if any(cell.strip() for cell in row[width:]):
                raise ReportError(f"{path.name}: extra CSV fields on row {row_index + 1}")
            row = row[:width]
        elif len(row) < width:
            # csv.reader preserves internal blank columns; only omitted trailing
            # cells are padded, never shifted into a different field.
            row = row + [""] * (width - len(row))

        person_number = parse_person_number(row[person_index], path, row_index + 1)
        if person_number in seen:
            raise ReportError(f"{path.name}: duplicate PersNr. on CSV row {row_index + 1}")
        seen.add(person_number)

        values: dict[str, str | int | None] = {}
        for column in DB_COLUMNS:
            source_index = report.header_indices.get(column)
            if source_index is None:
                values[column] = None
                continue
            cell = row[source_index].strip()
            if column == "pers_nr":
                values[column] = person_number
            elif column in DATE_COLUMNS:
                values[column] = parse_date(cell, column, path, row_index + 1)
            else:
                values[column] = cell

        if not str(values["name_vorname"] or "").strip():
            raise ReportError(f"{path.name}: missing Name, Vorname on CSV row {row_index + 1}")

        stamp = report.printed_at.strftime("%Y-%m-%d %H:%M:%S")
        values["lastinsertupdate"] = stamp
        values["filedate"] = stamp
        # TSV LOAD DATA uses \N as SQL NULL. A literal backslash-N is doubled.
        normalized_rows.append(list(values.values()))

    if len(normalized_rows) != report.footer_count:
        raise ReportError(
            f"{path.name}: footer says {report.footer_count} people, "
            f"but {len(normalized_rows)} data rows were parsed"
        )
    return normalized_rows


def parse_report(
    path: Path, text: str | None = None
) -> tuple[ParsedReport, list[list[str | int | None]]]:
    rows, header_index, header_indices, delimiter = load_rows_and_header(path, text)
    printed_at = parse_printed_at(rows, header_index, path)
    footer_index, footer_count = parse_footer_count(rows, header_index, path)
    report = ParsedReport(
        printed_at=printed_at,
        rows=rows,
        header_index=header_index,
        footer_index=footer_index,
        footer_count=footer_count,
        header_indices=header_indices,
        delimiter=delimiter,
    )
    normalized_rows = normalized_data_rows(report, path)
    return report, normalized_rows


def inspect_snapshot(path: Path, structure_only: bool = False) -> Snapshot:
    raw = path.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    text = decode_report_bytes(raw, path)
    if structure_only:
        rows, header_index, header_indices, delimiter = load_rows_and_header(path, text)
        printed_at = parse_printed_at(rows, header_index, path)
        footer_index, footer_count = parse_footer_count(rows, header_index, path)
        report = ParsedReport(
            printed_at=printed_at,
            rows=rows,
            header_index=header_index,
            footer_index=footer_index,
            footer_count=footer_count,
            header_indices=header_indices,
            delimiter=delimiter,
        )
        row_count = structural_data_row_count(report, path)
    else:
        report, normalized_rows = parse_report(path, text)
        row_count = len(normalized_rows)
    return Snapshot(
        path=path,
        printed_at=printed_at if structure_only else report.printed_at,
        sha256=digest,
        row_count=row_count,
    )


def choose_snapshots(snapshots: list[Snapshot], latest_per_day: bool) -> tuple[list[Snapshot], int]:
    by_day: dict[date, list[Snapshot]] = {}
    for snapshot in snapshots:
        by_day.setdefault(snapshot.printed_at.date(), []).append(snapshot)

    selected: list[Snapshot] = []
    dropped = 0
    for day, group in sorted(by_day.items()):
        unique: dict[str, Snapshot] = {}
        for snapshot in group:
            unique.setdefault(snapshot.sha256, snapshot)
        group = list(unique.values())
        dropped += len(by_day[day]) - len(group)

        if len(group) == 1:
            selected.extend(group)
            continue
        if not latest_per_day:
            names = ", ".join(snapshot.path.name for snapshot in group)
            raise ReportError(
                f"{day.isoformat()}: multiple different snapshots share a Druckdatum date ({names}); "
                "rerun with --latest-per-day to select the newest Druckdatum timestamp"
            )
        group.sort(key=lambda snapshot: snapshot.printed_at)
        if group[-1].printed_at == group[-2].printed_at:
            names = ", ".join(snapshot.path.name for snapshot in group if snapshot.printed_at == group[-1].printed_at)
            raise ReportError(f"{day.isoformat()}: conflicting snapshots have the same Druckdatum timestamp ({names})")
        dropped += len(group) - 1
        selected.append(group[-1])

    selected.sort(key=lambda snapshot: (snapshot.printed_at, snapshot.path.name.casefold()))
    return selected, dropped


def ensure_output_outside_repo(output: Path) -> None:
    resolved_output = output.resolve()
    source_path = Path(__file__).resolve()
    repo_roots = [parent for parent in source_path.parents if (parent / ".git").exists()]
    if any(
        resolved_output == root or root in resolved_output.parents
        for root in repo_roots
    ):
        raise ReportError(
            "The prepared file contains personal data; choose an output path outside the repository"
        )


def write_prepared_file(snapshots: list[Snapshot], output: Path) -> int:
    ensure_output_outside_repo(output)
    if output.resolve() in {snapshot.path.resolve() for snapshot in snapshots}:
        raise ReportError("Output path matches an input CSV; choose a separate TSV path")
    output.parent.mkdir(parents=True, exist_ok=True)
    temp_path: Path | None = None
    total_rows = 0
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="",
            dir=output.parent,
            prefix=output.name + ".",
            suffix=".partial",
            delete=False,
        ) as temp:
            temp_path = Path(temp.name)
            # Emit MariaDB LOAD DATA LOCAL INFILE escaped TSV. In particular,
            # a SQL NULL is the unescaped two-character token ``\N``. A CSV
            # writer would escape that backslash and turn it into literal text.
            temp.write("\t".join(DB_COLUMNS) + "\n")
            for snapshot in snapshots:
                raw = snapshot.path.read_bytes()
                if hashlib.sha256(raw).hexdigest() != snapshot.sha256:
                    raise ReportError(
                        f"{snapshot.path.name}: file changed after validation; rerun preprocessing"
                    )
                text = decode_report_bytes(raw, snapshot.path)
                _, rows = parse_report(snapshot.path, text)
                for row in rows:
                    temp.write("\t".join(escape_load_data(value) for value in row) + "\n")
                total_rows += len(rows)
        os.replace(temp_path, output)
        return total_rows
    except Exception:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)
        raise


def escape_load_data(value: str | int | None) -> str:
    """Escape one non-NULL field for LOAD DATA with ESCAPED BY '\\'."""
    if value is None:
        return r"\N"
    return (
        str(value)
        .replace("\\", "\\\\")
        .replace("\0", "\\0")
        .replace("\b", "\\b")
        .replace("\t", "\\t")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\x1a", "\\Z")
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_dir", type=Path, help="Folder containing the exported raw CSV attachments")
    parser.add_argument("--output", type=Path, help="Final TSV path; defaults beside the raw folder")
    parser.add_argument(
        "--latest-per-day",
        action="store_true",
        help="When different reports share a date, keep the latest Druckdatum timestamp",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Validate all files and report aggregate counts without writing output",
    )
    parser.add_argument(
        "--structure-only",
        action="store_true",
        help="With --validate-only, check headers, row widths, Druckdatum, and footer count; skip cell-value checks",
    )
    args = parser.parse_args(argv)

    if not args.input_dir.is_dir():
        parser.error(f"input directory doesn't exist: {args.input_dir}")
    files = sorted(
        (path for path in args.input_dir.iterdir() if path.is_file() and path.suffix.casefold() == ".csv"),
        key=lambda path: path.name.casefold(),
    )
    if not files:
        parser.error("no .csv files found in the input directory")
    if args.structure_only and not args.validate_only:
        parser.error("--structure-only can only be used with --validate-only")

    try:
        snapshots = [inspect_snapshot(path, structure_only=args.structure_only) for path in files]
        selected, dropped = choose_snapshots(snapshots, args.latest_per_day)
        total_rows = sum(snapshot.row_count for snapshot in selected)
        output = args.output or args.input_dir.parent / "prepared_personalakte_backfill.tsv"
        if not args.validate_only:
            written_rows = write_prepared_file(selected, output)
            if written_rows != total_rows:
                raise ReportError("file changed between validation and conversion; rerun preprocessing")

        first_date = selected[0].printed_at.date().isoformat()
        last_date = selected[-1].printed_at.date().isoformat()
        print(f"Raw CSV files checked: {len(files)}")
        print(f"Snapshots selected: {len(selected)}")
        print(f"Exact duplicates or superseded same-day files: {dropped}")
        print(f"Person rows: {total_rows}")
        print(f"Druckdatum date range: {first_date} through {last_date}")
        if args.structure_only:
            print("Headers, Druckdatum, row widths, and footer counts: valid; cell values were not checked")
        else:
            print("Footer counts, row widths, required headers, dates, and duplicate PersNr. values: valid")
        if args.validate_only:
            print("Validation only; no prepared file was written.")
        else:
            print(f"Prepared TSV: {output.resolve()}")
        return 0
    except (OSError, ReportError, csv.Error) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
