-- 本人の採点履歴のみ DELETE 可（レッスン単位リセット用）
CREATE POLICY "learning_item_attempts_delete_own"
  ON public.learning_item_attempts
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
