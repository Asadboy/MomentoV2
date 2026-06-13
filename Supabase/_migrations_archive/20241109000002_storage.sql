-- Storage Setup for Momento Photos

-- Create storage bucket for photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('momento-photos', 'momento-photos', false)
ON CONFLICT (id) DO NOTHING;

-- Storage Policy: Users can upload photos to their events
CREATE POLICY "Users can upload photos to their events"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'momento-photos' AND
  (storage.foldername(name))[1] IN (
    SELECT event_id::text FROM event_members
    WHERE user_id = auth.uid()
  )
);

-- Storage Policy: Users can view photos from their events
CREATE POLICY "Users can view photos from their events"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'momento-photos' AND
  (storage.foldername(name))[1] IN (
    SELECT event_id::text FROM event_members
    WHERE user_id = auth.uid()
  )
);

-- Storage Policy: Event creators can delete photos (moderation)
CREATE POLICY "Creators can delete photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'momento-photos' AND
  (storage.foldername(name))[1] IN (
    SELECT id::text FROM events
    WHERE creator_id = auth.uid()
  )
);

