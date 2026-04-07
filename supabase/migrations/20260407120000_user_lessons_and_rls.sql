-- =============================================================================
-- ユーザーオリジナル lessons + public/private。公式（BlogMAE）は lesson_kind = system。
-- course_key: 公式は従来どおり。ユーザーは user:<uuid>（クライアントが採番）。
-- =============================================================================

ALTER TABLE public.lessons
  ADD COLUMN IF NOT EXISTS lesson_kind text NOT NULL DEFAULT 'system',
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS visibility text;

-- 公式 5 コースのみ（既存データの正規化）
UPDATE public.lessons
SET
  lesson_kind = 'system',
  created_by = NULL,
  visibility = NULL
WHERE course_key IN (
  'basic',
  'beginner',
  'participle',
  'intermediate',
  'advanced'
);

-- 既存 CHECK / 新カラム整合
ALTER TABLE public.lessons DROP CONSTRAINT IF EXISTS lessons_course_key_check;

ALTER TABLE public.lessons
  ADD CONSTRAINT lessons_lesson_kind_check
  CHECK (lesson_kind = ANY (ARRAY['system'::text, 'user'::text]));

ALTER TABLE public.lessons
  ADD CONSTRAINT lessons_visibility_check
  CHECK (
    (lesson_kind = 'system' AND visibility IS NULL)
    OR (lesson_kind = 'user' AND visibility = ANY (ARRAY['public'::text, 'private'::text]))
  );

ALTER TABLE public.lessons
  ADD CONSTRAINT lessons_created_by_check
  CHECK (
    (lesson_kind = 'system' AND created_by IS NULL)
    OR (lesson_kind = 'user' AND created_by IS NOT NULL)
  );

ALTER TABLE public.lessons
  ADD CONSTRAINT lessons_course_key_format_check
  CHECK (
    (
      lesson_kind = 'system'
      AND course_key = ANY (
        ARRAY[
          'basic'::text,
          'beginner'::text,
          'participle'::text,
          'intermediate'::text,
          'advanced'::text
        ]
      )
    )
    OR (
      lesson_kind = 'user'
      AND course_key ~ '^user:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text
    )
  );

COMMENT ON COLUMN public.lessons.lesson_kind IS 'system = 公式 BlogMAE。user = ユーザー作成。';
COMMENT ON COLUMN public.lessons.visibility IS 'user のみ public / private。system は NULL。';
COMMENT ON COLUMN public.lessons.created_by IS 'user レッスンの所有者。system は NULL。';

CREATE INDEX IF NOT EXISTS lessons_created_by_idx ON public.lessons (created_by);
CREATE INDEX IF NOT EXISTS lessons_lesson_kind_visibility_idx
  ON public.lessons (lesson_kind, visibility);

-- ---------------------------------------------------------------------------
-- lessons RLS
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "lessons_select_authenticated" ON public.lessons;

CREATE POLICY "lessons_select_visible"
  ON public.lessons
  FOR SELECT
  TO authenticated
  USING (
    lesson_kind = 'system'
    OR created_by = auth.uid()
    OR (lesson_kind = 'user' AND visibility = 'public')
  );

CREATE POLICY "lessons_insert_own_user"
  ON public.lessons
  FOR INSERT
  TO authenticated
  WITH CHECK (
    lesson_kind = 'user'
    AND created_by = auth.uid()
    AND visibility = ANY (ARRAY['public'::text, 'private'::text])
  );

CREATE POLICY "lessons_update_own_user"
  ON public.lessons
  FOR UPDATE
  TO authenticated
  USING (lesson_kind = 'user' AND created_by = auth.uid())
  WITH CHECK (lesson_kind = 'user' AND created_by = auth.uid());

CREATE POLICY "lessons_delete_own_user"
  ON public.lessons
  FOR DELETE
  TO authenticated
  USING (lesson_kind = 'user' AND created_by = auth.uid());

-- ---------------------------------------------------------------------------
-- learning_items RLS（親 lesson が見える場合のみ）
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "learning_items_select_authenticated" ON public.learning_items;

CREATE POLICY "learning_items_select_visible"
  ON public.learning_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.lessons l
      WHERE l.id = learning_items.lesson_id
        AND (
          l.lesson_kind = 'system'
          OR l.created_by = auth.uid()
          OR (l.lesson_kind = 'user' AND l.visibility = 'public')
        )
    )
  );

CREATE POLICY "learning_items_insert_own_lesson"
  ON public.learning_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.lessons l
      WHERE l.id = learning_items.lesson_id
        AND l.lesson_kind = 'user'
        AND l.created_by = auth.uid()
    )
  );

CREATE POLICY "learning_items_update_own_lesson"
  ON public.learning_items
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.lessons l
      WHERE l.id = learning_items.lesson_id
        AND l.lesson_kind = 'user'
        AND l.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.lessons l
      WHERE l.id = learning_items.lesson_id
        AND l.lesson_kind = 'user'
        AND l.created_by = auth.uid()
    )
  );

CREATE POLICY "learning_items_delete_own_lesson"
  ON public.learning_items
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.lessons l
      WHERE l.id = learning_items.lesson_id
        AND l.lesson_kind = 'user'
        AND l.created_by = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- 採点は「参照可能な learning_item」のみ
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "learning_item_attempts_insert_own" ON public.learning_item_attempts;

CREATE POLICY "learning_item_attempts_insert_own_visible_item"
  ON public.learning_item_attempts
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.learning_items li
      JOIN public.lessons l ON l.id = li.lesson_id
      WHERE li.id = learning_item_attempts.learning_item_id
        AND (
          l.lesson_kind = 'system'
          OR l.created_by = auth.uid()
          OR (l.lesson_kind = 'user' AND l.visibility = 'public')
        )
    )
  );
