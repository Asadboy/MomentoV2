-- Make the avatars-bucket RLS policies case-insensitive on the user-id
-- comparison. PostgreSQL's auth.uid()::text is lowercase; some clients
-- (Swift's UUID.uuidString) produce uppercase. Comparing as strings
-- was making uploads silently fail RLS. LOWER on both sides removes
-- the trap entirely.

DROP POLICY IF EXISTS "avatars_owner_insert" ON storage.objects;
DROP POLICY IF EXISTS "avatars_owner_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_owner_delete" ON storage.objects;

CREATE POLICY "avatars_owner_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND LOWER((storage.foldername(name))[1]) = LOWER(auth.uid()::text)
);

CREATE POLICY "avatars_owner_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
  AND LOWER((storage.foldername(name))[1]) = LOWER(auth.uid()::text)
);

CREATE POLICY "avatars_owner_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars'
  AND LOWER((storage.foldername(name))[1]) = LOWER(auth.uid()::text)
);
