-- Add reactions support to photos table
-- Stores emoji reactions as JSONB: { "user_id": "❤️", "user_id_2": "😂" }

ALTER TABLE public.photos
ADD COLUMN reactions JSONB DEFAULT '{}'::jsonb;

-- Create index for faster reaction queries
CREATE INDEX idx_photos_reactions ON photos USING GIN (reactions);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Added reactions column to photos table!';
END $$;

