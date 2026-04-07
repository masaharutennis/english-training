-- =============================================================================
-- profiles（auth.users と 1:1）+ 解答履歴 learning_item_attempts
-- =============================================================================
-- 認証は Supabase Auth（メール+パスワード）。ローカルは config.toml の
-- [auth.email] enable_confirmations = false。リモートはダッシュボードで確認メールをオフ。
-- =============================================================================

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'ログインユーザー（auth.users と同期）。';

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY "profiles_update_own"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- 新規ユーザー作成時に profiles へ1行（SECURITY DEFINER で RLS を迂回）
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (new.id, new.email);
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();

INSERT INTO public.profiles (id, email)
SELECT id, email
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- learning_item_attempts（履歴。最新行が「直近スコア」）
-- ---------------------------------------------------------------------------
CREATE TABLE public.learning_item_attempts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  learning_item_id bigint NOT NULL REFERENCES public.learning_items (id) ON DELETE CASCADE,
  score integer NOT NULL CHECK (score >= 0 AND score <= 100),
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.learning_item_attempts IS 'ユーザーごとの採点履歴。';

CREATE INDEX learning_item_attempts_user_item_created_idx
  ON public.learning_item_attempts (user_id, learning_item_id, created_at DESC);

CREATE INDEX learning_item_attempts_user_created_idx
  ON public.learning_item_attempts (user_id, created_at DESC);

ALTER TABLE public.learning_item_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "learning_item_attempts_select_own"
  ON public.learning_item_attempts
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "learning_item_attempts_insert_own"
  ON public.learning_item_attempts
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 教材はログインユーザーのみ参照（スコア紐づけのため）
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "lessons_select_public" ON public.lessons;
CREATE POLICY "lessons_select_authenticated"
  ON public.lessons
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "learning_items_select_public" ON public.learning_items;
CREATE POLICY "learning_items_select_authenticated"
  ON public.learning_items
  FOR SELECT
  TO authenticated
  USING (true);
