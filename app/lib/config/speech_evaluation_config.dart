/// 発話採点モード（コード上のみ切替。UI なし）。
///
/// `true`（既定）: API 不使用。単語整列（赤表示は既存 [EnglishAnswerDiff]）でスコアを **10 点刻み**。
/// `false`: 従来どおり `CORRECTION_API_BASE_URL` 経由で ChatGPT 採点・短文アドバイス。
const bool kUseLocalWordDiffSpeechEvaluation = true;
