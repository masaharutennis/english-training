#!/usr/bin/env python3
"""スクレイプ出力 CSV から supabase/seeds/learning_items.sql を再生成する。リポジトリルートで: python3 tools/generate_learning_seed.py"""
from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_DIR = ROOT / "tools" / "scraping" / "output"
OUT = ROOT / "supabase" / "seeds" / "learning_items.sql"

# lessons = コース 5 件（マイグレーションの INSERT と揃える）
LESSONS: list[tuple[str, str, int]] = [
    ("basic", "BlogMAE 基礎編", 1),
    ("beginner", "BlogMAE 初級編", 2),
    ("participle", "BlogMAE 分詞・関係代名詞編", 3),
    ("intermediate", "BlogMAE 中級編", 4),
    ("advanced", "BlogMAE 上級編", 5),
]

COURSES: list[tuple[str, str]] = [
    ("basic", "blogmae_basic.csv"),
    ("beginner", "blogmae_beginner.csv"),
    ("participle", "blogmae_participle.csv"),
    ("intermediate", "blogmae_intermediate.csv"),
    ("advanced", "blogmae_advanced.csv"),
]


def sql_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "''") + "'"


def main() -> None:
    parts: list[str] = [
        "-- 自動生成: python3 tools/generate_learning_seed.py",
        "-- 適用例: npx supabase db query --linked -f supabase/seeds/learning_items.sql",
        "-- （ローカル）supabase db reset 後にも config の db.seed で読み込まれる",
        "",
        "TRUNCATE public.learning_items RESTART IDENTITY CASCADE;",
        "TRUNCATE public.lessons RESTART IDENTITY CASCADE;",
        "",
    ]
    for course_key, title, sort_order in LESSONS:
        parts.append(
            "INSERT INTO public.lessons (course_key, title, sort_order) VALUES ("
            f"{sql_str(course_key)}, {sql_str(title)}, {sort_order});"
        )
    parts.append("")
    n_items = 0
    for course_key, filename in COURSES:
        path = CSV_DIR / filename
        with path.open(newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for row in reader:
                lid = int(str(row["id"]).strip())
                grammar = str(row.get("grammar", "")).strip()
                english = str(row["english"]).strip()
                japanese = str(row["japanese"]).strip()
                parts.append(
                    "INSERT INTO public.learning_items (lesson_id, item_number, grammar, english, japanese) "
                    "SELECT id, "
                    f"{lid}, {sql_str(grammar)}, {sql_str(english)}, {sql_str(japanese)} "
                    "FROM public.lessons WHERE course_key = "
                    f"{sql_str(course_key)};"
                )
                n_items += 1
    OUT.write_text("\n".join(parts) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(LESSONS)} lessons, {n_items} items)")


if __name__ == "__main__":
    main()
