-- Migration: Add starts_at and ends_at to events table
-- Date: December 21, 2025
-- Purpose: Support event start/end times for photo capture window

-- Add starts_at column (when event goes live, photos can be taken)
ALTER TABLE events 
ADD COLUMN IF NOT EXISTS starts_at TIMESTAMPTZ;

-- Add ends_at column (when photo-taking stops)
ALTER TABLE events 
ADD COLUMN IF NOT EXISTS ends_at TIMESTAMPTZ;

-- Update existing events: set starts_at to created_at and ends_at to release_at
-- (release_at was previously used as the reveal time, now it will be 24h after ends_at)
UPDATE events 
SET 
  starts_at = COALESCE(starts_at, created_at),
  ends_at = COALESCE(ends_at, release_at)
WHERE starts_at IS NULL OR ends_at IS NULL;

-- For future events, we'll calculate release_at as 24h after ends_at
-- Or allow custom reveal times

-- Add index for querying events by time
CREATE INDEX IF NOT EXISTS idx_events_starts_at ON events(starts_at);
CREATE INDEX IF NOT EXISTS idx_events_ends_at ON events(ends_at);

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Migration complete: Added starts_at and ends_at columns to events table';
END $$;

