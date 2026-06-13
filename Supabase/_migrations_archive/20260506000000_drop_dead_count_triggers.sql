-- Drop dead member_count / photo_count triggers and their functions.
--
-- The events table no longer has member_count or photo_count columns —
-- counts are hydrated client-side via getEventMemberCount /
-- getEventPhotoCount. The triggers from the initial schema
-- (20241109000000_initial_schema.sql) still referenced those columns
-- and were silently failing every INSERT into event_members and photos,
-- which rolled back the row insert. Symptoms: newly created events
-- have no creator_id member row, and getMyEvents filters them out on
-- refresh; new photos fail to upload.
--
-- Two trigger names exist for each table because both the original
-- (event_member_count_trigger / event_photo_count_trigger) and a later
-- duplicate (trg_event_member_count / trg_event_photo_count) were
-- created. We drop both.

DROP TRIGGER IF EXISTS event_member_count_trigger ON event_members;
DROP TRIGGER IF EXISTS trg_event_member_count ON event_members;
DROP TRIGGER IF EXISTS event_photo_count_trigger ON photos;
DROP TRIGGER IF EXISTS trg_event_photo_count ON photos;

DROP FUNCTION IF EXISTS update_event_member_count();
DROP FUNCTION IF EXISTS update_event_photo_count();
