-- Beta fix: Remove photo limits per user
-- Change default from 5 to 9999 (effectively unlimited)
-- This allows unlimited uploads during beta testing

ALTER TABLE events
ALTER COLUMN max_photos_per_user SET DEFAULT 9999;

-- Update existing events to use new limit
UPDATE events SET max_photos_per_user = 9999;
