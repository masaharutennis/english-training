"""
BlogMAE 瞬間英作トレーニング スクレイパー.

.post_content 内のアコーディオンから id, grammar, english, japanese を抽出する。

プリセット::

    python blogmae.py              # 基礎編 → output/blogmae_basic.csv
    python blogmae.py basic
    python blogmae.py beginner       # 初級編 → output/blogmae_beginner.csv
    python blogmae.py participle   # 分詞と関係代名詞編 (pronunciation1-2)
    python blogmae.py intermediate # 中級編 (pronunciation3)
    python blogmae.py advanced     # 上級編 (pronunciation4)

任意 URL / 出力::

    python blogmae.py --url https://blogmae.com/ieltsblog-pronunciation2/ -o output/foo.csv

セットアップ（初回）::

    cd tools/scraping
    python3 -m venv .venv
    source .venv/bin/activate   # Windows: .venv\\Scripts\\activate
    pip install -r ../requirements.txt
"""

from __future__ import annotations

import argparse
import csv
import html
import re
import sys
from pathlib import Path

import requests
from bs4 import BeautifulSoup

SCRIPT_DIR = Path(__file__).resolve().parent
OUT_DIR = SCRIPT_DIR / "output"
HEADERS = ["id", "grammar", "english", "japanese"]

PRESETS: dict[str, tuple[str, str]] = {
    "basic": (
        "https://blogmae.com/ieltsblog-pronunciation1/",
        "blogmae_basic.csv",
    ),
    "beginner": (
        "https://blogmae.com/ieltsblog-pronunciation2/",
        "blogmae_beginner.csv",
    ),
    # ieltsblog-pronunciation1-2
    "participle": (
        "https://blogmae.com/ieltsblog-pronunciation1-2/",
        "blogmae_participle.csv",
    ),
    "intermediate": (
        "https://blogmae.com/ieltsblog-pronunciation3/",
        "blogmae_intermediate.csv",
    ),
    "advanced": (
        "https://blogmae.com/ieltsblog-pronunciation4/",
        "blogmae_advanced.csv",
    ),
}


def fetch_html(url: str) -> str:
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    r.encoding = r.apparent_encoding
    return r.text


def _normalize_heading_text(s: str) -> str:
    return (
        s.replace("\u00a0", "")
        .replace("\u200b", "")
        .replace(" ", "")
        .replace("\t", "")
        .strip()
    )


def _grammar_heading_from_p(tag) -> str | None:
    """<p> が文法セクション見出しのときラベルを返す（それ以外は None）。"""
    if tag.name != "p":
        return None
    for strong in tag.find_all("strong"):
        t = _normalize_heading_text(strong.get_text(strip=True))
        if len(t) >= 2 and t.startswith("＜") and t.endswith("＞"):
            return t[1:-1]
    plain = tag.get_text(separator="", strip=True)
    spaced = plain.replace("\u00a0", " ").replace("\u200b", "")
    spaced = re.sub(r"\s+", " ", spaced).strip()
    m = re.match(r"^【(.+)】$", spaced)
    if not m:
        return None
    inner = m.group(1).strip()
    if not inner or len(inner) > 120:
        return None
    if inner == "目次" or inner.startswith("1."):
        return None
    return inner


def parse_rows(soup: BeautifulSoup) -> list[dict[str, str]]:
    post = soup.select_one(".post_content")
    if not post:
        raise ValueError(".post_content が見つかりません")

    current_grammar = ""
    rows: list[dict[str, str]] = []

    for tag in post.find_all(["p", "details"], recursive=True):
        # 基礎編: <strong>＜過去形＞</strong> / 分詞編: 【現在分詞修飾】 / 上級編: 【上級編】 など
        if tag.name == "p":
            g = _grammar_heading_from_p(tag)
            if g:
                current_grammar = g
        elif tag.name == "details" and "swell-block-accordion__item" in (tag.get("class") or []):
            label_el = tag.select_one(".swell-block-accordion__label")
            body_el = tag.select_one(".swell-block-accordion__body")
            if not label_el or not body_el:
                continue
            raw_label = label_el.get_text(strip=True)
            m = re.match(r"^(\d+)\.\s*(.+)$", raw_label)
            if not m:
                continue
            qid, japanese = m.group(1), m.group(2)
            english = body_el.get_text(separator="\n", strip=True)
            english = html.unescape(english)
            english = re.sub(r"\s*\n\s*", " ", english).strip()
            rows.append(
                {
                    "id": qid,
                    "grammar": current_grammar,
                    "english": english,
                    "japanese": japanese,
                }
            )
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="BlogMAE 瞬間英作 CSV 抽出")
    parser.add_argument(
        "preset",
        nargs="?",
        default="basic",
        choices=sorted(PRESETS.keys()),
        help=(
            "basic=基礎編(1), beginner=初級編(2), participle=分詞・関係代名詞(1-2), "
            "intermediate=中級編(3), advanced=上級編(4)（省略時は basic）"
        ),
    )
    parser.add_argument("--url", help="記事 URL（指定時は preset の URL を上書き）")
    parser.add_argument(
        "-o",
        "--output",
        help="出力 CSV ファイル名（output/ 相対。指定時は preset のファイル名を上書き）",
    )
    args = parser.parse_args(argv)

    default_url, default_name = PRESETS[args.preset]
    url = args.url or default_url
    rel_name = args.output or default_name
    csv_path = OUT_DIR / Path(rel_name).name

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    soup = BeautifulSoup(fetch_html(url), "html.parser")
    rows = parse_rows(soup)
    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=HEADERS)
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {len(rows)} rows -> {csv_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
