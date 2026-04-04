-- =============================================================================
-- learning: lessons（5コース）+ learning_items
-- =============================================================================
-- lessons … コース（basic / beginner / participle / intermediate / advanced）。
-- learning_items … 各問。item_number = コース内番号（元 CSV の id）。
-- ゼロからの再現用にこの1本のみ。ローカルは supabase db reset、リモートは新規プロジェクトか
-- 履歴の整理（migration repair 等）が必要な場合があります。
-- =============================================================================

-- ---------------------------------------------------------------------------
-- lessons（5 行・course_key UNIQUE）
-- ---------------------------------------------------------------------------
CREATE TABLE public.lessons (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  course_key text NOT NULL,
  title text NOT NULL DEFAULT '',
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lessons_course_key_check CHECK (
    course_key = ANY (ARRAY[
      'basic'::text,
      'beginner'::text,
      'participle'::text,
      'intermediate'::text,
      'advanced'::text
    ])
  ),
  CONSTRAINT lessons_course_key_unique UNIQUE (course_key)
);

COMMENT ON TABLE public.lessons IS 'コース単位（全5件）。ベーシック・初級など。';

CREATE INDEX lessons_sort_order_idx ON public.lessons (sort_order);

ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "lessons_select_public"
  ON public.lessons
  FOR SELECT
  TO anon, authenticated
  USING (true);

INSERT INTO public.lessons (course_key, title, sort_order) VALUES
  ('basic', 'BlogMAE 基礎編', 1),
  ('beginner', 'BlogMAE 初級編', 2),
  ('participle', 'BlogMAE 分詞・関係代名詞編', 3),
  ('intermediate', 'BlogMAE 中級編', 4),
  ('advanced', 'BlogMAE 上級編', 5);

-- ---------------------------------------------------------------------------
-- learning_items（lesson_id + item_number）
-- ---------------------------------------------------------------------------
CREATE TABLE public.learning_items (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lesson_id bigint NOT NULL REFERENCES public.lessons (id) ON DELETE CASCADE,
  item_number integer NOT NULL,
  grammar text NOT NULL DEFAULT '',
  english text NOT NULL,
  japanese text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT learning_items_lesson_item_unique UNIQUE (lesson_id, item_number)
);

COMMENT ON TABLE public.learning_items IS 'コース（lessons）に紐づく各問。item_number はコース内通し（元CSV id）。';

CREATE INDEX learning_items_lesson_id_idx ON public.learning_items (lesson_id);

ALTER TABLE public.learning_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "learning_items_select_public"
  ON public.learning_items
  FOR SELECT
  TO anon, authenticated
  USING (true);
