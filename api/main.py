"""
瞬間英作文の添削 API（OpenAI はここだけ）。
Flutter アプリは本サーバーの URL のみ知ればよく、API キーは持たない。
Vercel デプロイ参考: https://github.com/TomoyaKuroda/Vercel-FastAPI
"""
from __future__ import annotations

import json
import os
import re
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="English Training — Composition API")

_origins_env = os.getenv("ALLOWED_ORIGINS", "").strip()
# 「*」のときはブラウザ仕様上 allow_credentials と併用できない
if _origins_env == "*":
    _cors_origins = ["*"]
    _cors_credentials = False
elif _origins_env:
    _cors_origins = [o.strip() for o in _origins_env.split(",") if o.strip()]
    _cors_credentials = True
else:
    _cors_origins = [
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ]
    _cors_credentials = True

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=_cors_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)


class CorrectRequest(BaseModel):
    grammar: str = Field(..., description="文法・単元")
    japanese: str = Field(..., description="お題（日本語）")
    english: str = Field("", description="参考英文（教材）")
    user_english: str = Field(..., description="学習者の英語")


class CorrectionOut(BaseModel):
    score: int
    grammar_feedback: str
    natural_feedback: str
    vocabulary_feedback: str
    corrected_answer: str
    model_answer: str
    short_advice: str


class EvaluateSpeechOut(BaseModel):
    score: int
    advice: str


class DrillSuggestRequest(BaseModel):
    direction: str = Field(
        ...,
        description="ja_to_en: 日本語お題から英文を生成 / en_to_ja: 英文から日本語お題を生成",
    )
    grammar: str = Field("", description="任意の文法タグ（ヒント）")
    source_text: str = Field(..., min_length=1, description="変換元のテキスト")


class DrillSuggestOut(BaseModel):
    text: str


@app.get("/")
async def root():
    return {"ok": True, "service": "composition-api"}


def _build_user_prompt(*, grammar: str, japanese: str, english_ref: str, user_english: str) -> str:
    ref = english_ref.strip() or "（教材に参考英文がありません）"
    lines = [
        "あなたは英語の瞬間英作文を添削するAIです。",
        "以下の日本語の意味を英語で表現する問題に対し、学習者が英文を書きました。",
        "文法単元・ニュアンスを踏まえて添削してください。",
        "",
        "【文法・単元】",
        grammar,
        "",
        "【お題（日本語）】",
        japanese,
        "",
        "【参考英文（教材・目安。別表現も認める）】",
        ref,
        "",
        "【学習者の英語】",
        user_english,
        "",
        "以下のキーを持つJSONのみを返してください（他のテキスト禁止）:",
        "{",
        '  "score": <0-100 の整数>,',
        '  "grammar_feedback": "<文法のコメント（日本語）>",',
        '  "natural_feedback": "<自然さのコメント（日本語）>",',
        '  "vocabulary_feedback": "<語彙・改善ポイント（日本語）>",',
        '  "corrected_answer": "<より自然な英語表現（英文のみ）>",',
        '  "model_answer": "<模範回答となる英文（教材と近くてもよい）>",',
        '  "short_advice": "<総合的な短いアドバイス（日本語）>"',
        "}",
    ]
    return "\n".join(lines)


def _extract_json_object(raw: str) -> str:
    s = raw.strip()
    if s.startswith("```"):
        s = re.sub(r"^```(?:json)?\s*", "", s, flags=re.IGNORECASE)
        s = re.sub(r"\s*```\s*$", "", s)
        s = s.strip()
    start, end = s.find("{"), s.rfind("}")
    if start >= 0 and end > start:
        return s[start : end + 1]
    return s


def _parse_correction_content(content: str) -> dict[str, Any]:
    blob = _extract_json_object(content)
    try:
        data = json.loads(blob)
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=502, detail=f"OpenAI の JSON が不正: {e}") from e
    return data


@app.post("/v1/composition/correct", response_model=CorrectionOut)
async def composition_correct(body: CorrectRequest) -> CorrectionOut:
    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="OPENAI_API_KEY がサーバー環境変数に設定されていません。",
        )

    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini").strip() or "gpt-4o-mini"
    base = os.getenv("OPENAI_API_BASE", "https://api.openai.com/v1").rstrip("/")
    url = f"{base}/chat/completions"

    system = (
        "You are an English composition coach for Japanese learners (瞬間英作文). "
        "Always respond with a single JSON object only, no markdown fences, matching the user-requested schema. "
        "Use Japanese for all string values except model_answer and corrected_answer which must be natural English."
    )
    user_prompt = _build_user_prompt(
        grammar=body.grammar,
        japanese=body.japanese,
        english_ref=body.english,
        user_english=body.user_english,
    )

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user_prompt},
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.4,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        r = await client.post(
            url,
            json=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
            },
        )

    if r.status_code < 200 or r.status_code >= 300:
        snippet = r.text[:300] + ("…" if len(r.text) > 300 else "")
        raise HTTPException(
            status_code=502,
            detail=f"OpenAI API エラー ({r.status_code}): {snippet}",
        )

    try:
        outer = r.json()
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=502, detail=f"OpenAI 応答が JSON ではありません: {e}") from e

    choices = outer.get("choices") or []
    if not choices:
        raise HTTPException(status_code=502, detail="OpenAI 応答に choices がありません")

    msg = (choices[0] or {}).get("message") or {}
    content = msg.get("content")
    if not content:
        raise HTTPException(status_code=502, detail="OpenAI から空の content が返りました")

    data = _parse_correction_content(content)

    def _score(v: Any) -> int:
        if v is None:
            return 0
        if isinstance(v, bool):
            return int(v)
        if isinstance(v, int):
            return max(0, min(100, v))
        if isinstance(v, float):
            return max(0, min(100, int(round(v))))
        try:
            return max(0, min(100, int(float(str(v)))))
        except (TypeError, ValueError):
            return 0

    try:
        return CorrectionOut(
            score=_score(data.get("score")),
            grammar_feedback=str(data.get("grammar_feedback", "")),
            natural_feedback=str(data.get("natural_feedback", "")),
            vocabulary_feedback=str(data.get("vocabulary_feedback", "")),
            corrected_answer=str(data.get("corrected_answer", "")),
            model_answer=str(data.get("model_answer", "")),
            short_advice=str(data.get("short_advice", "")),
        )
    except (TypeError, ValueError) as e:
        raise HTTPException(status_code=502, detail=f"添削 JSON の型が不正: {e}") from e


def _build_evaluate_speech_prompt(*, grammar: str, japanese: str, english_ref: str, user_english: str) -> str:
    ref = english_ref.strip() or "（模範英文の参考なし）"
    return "\n".join(
        [
            "あなたは英語の発話練習の採点者です。",
            "学習者は日本語の意味を英語で話しました（音声認識のテキストが渡ります）。",
            "模範英文と完全一致しなくてよいです。日本語の意味を、どれだけ適切な英語で言えているかで評価してください。",
            "音声認識の誤変換も考慮してください。",
            "句読点（ピリオド、クエスチョンマーク、カンマ等）は発話では付きにくいため、"
            "模範解答にあって学習者のテキストに無いだけでは減点しないでください。",
            "",
            "【文法・単元】",
            grammar,
            "",
            "【お題（日本語）】",
            japanese,
            "",
            "【模範英文（参考。別の正しい言い方もあり得る）】",
            ref,
            "",
            "【学習者の英語（発話認識結果）】",
            user_english if user_english.strip() else "（空または聞き取れず）",
            "",
            "次のキーだけを持つJSONを返してください（他のテキスト禁止）:",
            "{",
            '  "score": <0-100 の整数。意味の伝わり方・文法の妥当性の総合>,',
            '  "advice": "<日本語で1〜3文。良い点を認めつつ、具体的な改善があれば短く。褒め言葉だけにしない>"',
            "}",
        ]
    )


@app.post("/v1/composition/evaluate_speech", response_model=EvaluateSpeechOut)
async def evaluate_speech(body: CorrectRequest) -> EvaluateSpeechOut:
    """発話テキストの簡易評価（スコア + 短いアドバイスのみ）。"""
    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="OPENAI_API_KEY がサーバー環境変数に設定されていません。",
        )

    # 発話評価だけ速い・安いモデルにしたい場合は OPENAI_EVAL_SPEECH_MODEL を優先
    model = (
        os.getenv("OPENAI_EVAL_SPEECH_MODEL", "").strip()
        or os.getenv("OPENAI_MODEL", "gpt-4o-mini").strip()
        or "gpt-4o-mini"
    )
    base = os.getenv("OPENAI_API_BASE", "https://api.openai.com/v1").rstrip("/")
    url = f"{base}/chat/completions"

    system = (
        "You evaluate spoken English for Japanese learners. "
        "Respond with a single JSON object only, no markdown. "
        "The \"advice\" value must be in Japanese only. "
        "The \"score\" is an integer 0-100. "
        "Do not penalize missing punctuation (periods, question marks, commas) compared to a written model answer; "
        "speech transcripts often omit them."
    )
    user_prompt = _build_evaluate_speech_prompt(
        grammar=body.grammar,
        japanese=body.japanese,
        english_ref=body.english,
        user_english=body.user_english,
    )

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user_prompt},
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.35,
        "max_tokens": 400,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        r = await client.post(
            url,
            json=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
            },
        )

    if r.status_code < 200 or r.status_code >= 300:
        snippet = r.text[:300] + ("…" if len(r.text) > 300 else "")
        raise HTTPException(
            status_code=502,
            detail=f"OpenAI API エラー ({r.status_code}): {snippet}",
        )

    try:
        outer = r.json()
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=502, detail=f"OpenAI 応答が JSON ではありません: {e}") from e

    choices = outer.get("choices") or []
    if not choices:
        raise HTTPException(status_code=502, detail="OpenAI 応答に choices がありません")

    msg = (choices[0] or {}).get("message") or {}
    content = msg.get("content")
    if not content:
        raise HTTPException(status_code=502, detail="OpenAI から空の content が返りました")

    data = _parse_correction_content(content)

    def _score(v: Any) -> int:
        if v is None:
            return 0
        if isinstance(v, bool):
            return int(v)
        if isinstance(v, int):
            return max(0, min(100, v))
        if isinstance(v, float):
            return max(0, min(100, int(round(v))))
        try:
            return max(0, min(100, int(float(str(v)))))
        except (TypeError, ValueError):
            return 0

    return EvaluateSpeechOut(
        score=_score(data.get("score")),
        advice=str(data.get("advice", "")),
    )


def _build_drill_suggest_prompt(*, direction: str, grammar: str, source_text: str) -> str:
    g = grammar.strip() or "（指定なし）"
    if direction == "ja_to_en":
        return "\n".join(
            [
                "あなたは瞬間英作文の教材作成を手伝います。",
                "学習者が日本語の意味を英語で言う問題用に、模範となる英文を1つだけ返してください。",
                "口語・会話調でも文語でも、日本語の意味に忠実で自然な英語にしてください。",
                "文法タグがあれば、その範囲の表現を優先してください（無理に合わせない）。",
                "",
                "【文法タグ（任意）】",
                g,
                "",
                "【お題（日本語）】",
                source_text.strip(),
                "",
                'JSONのみ返す: {"text": "<英文のみ。説明や引用符は不要>"}',
            ]
        )
    if direction == "en_to_ja":
        return "\n".join(
            [
                "あなたは瞬間英作文の教材作成を手伝います。",
                "与えられた英文を、学習者にお題として見せる自然な日本語（1文〜短い文）にしてください。",
                "意味が伝わる教科書調の日本語にしてください。",
                "",
                "【文法タグ（任意）】",
                g,
                "",
                "【模範英文】",
                source_text.strip(),
                "",
                'JSONのみ返す: {"text": "<日本語のお題のみ。説明不要>"}',
            ]
        )
    raise ValueError(f"invalid direction: {direction}")


@app.post("/v1/composition/suggest_drill_line", response_model=DrillSuggestOut)
async def suggest_drill_line(body: DrillSuggestRequest) -> DrillSuggestOut:
    """問題登録用: 日本語→英文、または英文→日本語お題を ChatGPT で提案。"""
    if body.direction not in ("ja_to_en", "en_to_ja"):
        raise HTTPException(status_code=400, detail="direction は ja_to_en か en_to_ja のみです")

    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="OPENAI_API_KEY がサーバー環境変数に設定されていません。",
        )

    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini").strip() or "gpt-4o-mini"
    base = os.getenv("OPENAI_API_BASE", "https://api.openai.com/v1").rstrip("/")
    url = f"{base}/chat/completions"

    system = (
        "You help author English drill items for Japanese learners (瞬間英作文). "
        "Always respond with a single JSON object only, no markdown, with key \"text\" only."
    )
    user_prompt = _build_drill_suggest_prompt(
        direction=body.direction,
        grammar=body.grammar,
        source_text=body.source_text,
    )

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user_prompt},
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.35,
        "max_tokens": 600,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        r = await client.post(
            url,
            json=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
            },
        )

    if r.status_code < 200 or r.status_code >= 300:
        snippet = r.text[:300] + ("…" if len(r.text) > 300 else "")
        raise HTTPException(
            status_code=502,
            detail=f"OpenAI API エラー ({r.status_code}): {snippet}",
        )

    try:
        outer = r.json()
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=502, detail=f"OpenAI 応答が JSON ではありません: {e}") from e

    choices = outer.get("choices") or []
    if not choices:
        raise HTTPException(status_code=502, detail="OpenAI 応答に choices がありません")

    msg = (choices[0] or {}).get("message") or {}
    content = msg.get("content")
    if not content:
        raise HTTPException(status_code=502, detail="OpenAI から空の content が返りました")

    data = _parse_correction_content(content)
    text = str(data.get("text", "")).strip()
    if not text:
        raise HTTPException(status_code=502, detail="提案テキストが空でした")

    return DrillSuggestOut(text=text)
