-- =====================================================================
-- Apple Guideline 1.2 (UGC): in-app content reporting + auto-hide.
-- =====================================================================
-- Every photo gets an in-app "Report" action. A report inserts a row
-- here; an AFTER INSERT trigger hides the photo for everyone once it
-- reaches REPORT_THRESHOLD distinct reporters. Threshold is 1: a single
-- report removes the photo for all members pending operator review
-- (appropriate for small private events). This makes objectionable
-- content self-remove within seconds with no human in the loop, which
-- satisfies 1.2(c) ("act on reports").
--
-- hidden_at is the single "hidden from everyone" signal. The existing
-- flagPhoto/is_flagged path is unrelated and left as-is.
-- =====================================================================

ALTER TABLE public.photos
  ADD COLUMN IF NOT EXISTS hidden_at timestamptz;

CREATE TABLE IF NOT EXISTS public.photo_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id uuid NOT NULL REFERENCES public.photos(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL DEFAULT auth.uid(),
  reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (photo_id, reporter_id)
);

ALTER TABLE public.photo_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can file their own reports" ON public.photo_reports;
CREATE POLICY "Users can file their own reports"
  ON public.photo_reports
  FOR INSERT TO authenticated
  WITH CHECK (reporter_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can read their own reports" ON public.photo_reports;
CREATE POLICY "Users can read their own reports"
  ON public.photo_reports
  FOR SELECT TO authenticated
  USING (reporter_id = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.hide_photo_on_report()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  report_threshold CONSTANT INTEGER := 1;
  reporter_count INTEGER;
BEGIN
  SELECT count(DISTINCT reporter_id) INTO reporter_count
  FROM public.photo_reports
  WHERE photo_id = NEW.photo_id;

  IF reporter_count >= report_threshold THEN
    UPDATE public.photos
      SET hidden_at = now()
      WHERE id = NEW.photo_id
        AND hidden_at IS NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS hide_photo_on_report ON public.photo_reports;
CREATE TRIGGER hide_photo_on_report
  AFTER INSERT ON public.photo_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.hide_photo_on_report();

REVOKE ALL ON FUNCTION public.hide_photo_on_report() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hide_photo_on_report() TO authenticated;
