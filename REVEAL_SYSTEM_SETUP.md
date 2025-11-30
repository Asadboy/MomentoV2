# Photo Reveal System - Setup Guide

## ✅ What's Already Done

1. **Edge Function Created & Deployed** ✅
   - Function: `reveal-photos`
   - Location: `Supabase/functions/reveal-photos/index.ts`
   - Status: Deployed to Supabase
   - URL: `https://thnbjfcmawwaxvihggjm.supabase.co/functions/v1/reveal-photos`

2. **Swift UI Components** ✅
   - HapticsManager.swift - Haptic feedback system
   - PhotoRevealCard.swift - Card flip animation
   - RevealView.swift - Full reveal experience with confetti
   - PremiumEventCard.swift - Updated with "Ready to Reveal" state
   - ContentView.swift - Routes to reveal experience

---

## 🔧 Manual Setup Required (5 minutes)

### Step 1: Run Database Migration

The reactions column needs to be added to the photos table.

**Option A: Via Supabase Dashboard (Easiest)**
1. Go to: https://supabase.com/dashboard/project/thnbjfcmawwaxvihggjm/editor
2. Click "SQL Editor" in left sidebar
3. Paste this SQL:

```sql
-- Add reactions support to photos table
ALTER TABLE public.photos
ADD COLUMN IF NOT EXISTS reactions JSONB DEFAULT '{}'::jsonb;

-- Create index for faster reaction queries
CREATE INDEX IF NOT EXISTS idx_photos_reactions ON photos USING GIN (reactions);
```

4. Click "Run" (bottom right)
5. Should see: "Success. No rows returned"

---

### Step 2: Setup Cron Job (Auto-reveal)

The Edge Function runs hourly to mark events as revealed after 24h.

**Via Supabase Dashboard:**

1. Go to: https://supabase.com/dashboard/project/thnbjfcmawwaxvihggjm/editor
2. Click "SQL Editor"
3. Paste this SQL:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule reveal function to run every hour
SELECT cron.schedule(
  'reveal-photos-hourly',
  '0 * * * *',  -- Every hour at minute 0
  $$
  SELECT
    net.http_post(
      url:='https://thnbjfcmawwaxvihggjm.supabase.co/functions/v1/reveal-photos',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRobmJqZmNtYXd3YXh2aWhnZ2ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzE0MjI4MTksImV4cCI6MjA0Njk5ODgxOX0.ULh7WPtPLCZ_r-Fq5Pegjhnr3BhQ0cE4ELEsOkFfd2dElT3Fxmq_Fmrq4lN5fKn9qPTzFubaVRYjPtbHQrwhtw"}'::jsonb,
      body:='{}'::jsonb
    ) AS request_id;
  $$
);
```

4. Click "Run"
5. Should see: Success!

**Verify Cron Job:**
```sql
-- Check if cron job is scheduled
SELECT * FROM cron.job;
```

You should see `reveal-photos-hourly` in the results.

---

### Step 3: Test the Edge Function Manually

Before waiting for the cron, test the function works:

**Via Terminal:**
```bash
curl -X POST "https://thnbjfcmawwaxvihggjm.supabase.co/functions/v1/reveal-photos" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRobmJqZmNtYXd3YXh2aWhnZ2ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzE0MjI4MTksImV4cCI6MjA0Njk5ODgxOX0.ULh7WPtPLCZ_r-Fq5Pegjhnr3BhQ0cE4ELEsOkFfd2dElT3Fxmq_Fmrq4lN5fKn9qPTzFubaVRYjPtbHQrwhtw" \
  -H "Content-Type: application/json"
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Revealed 0 events",
  "revealed_count": 0
}
```

(It will be 0 if no events are ready to reveal yet)

---

## 🎨 How the Reveal System Works

### User Flow:

1. **Event Created**
   - User creates event with release time
   - Photos can be taken during 24h window

2. **Live Period (0-24h after release)**
   - Event shows "Live now" with camera button
   - Users tap to take photos
   - Photos upload to storage

3. **Ready to Reveal (24h+ after release)**
   - Edge Function marks event as `is_revealed = true`
   - Event card starts glowing with purple/blue gradient
   - Button changes to sparkles icon with "Reveal" text
   - Subtitle: "Ready to reveal! ✨ Tap now"

4. **Tap to Reveal**
   - Opens full-screen RevealView
   - Photos appear face-down (purple gradient cards)
   - "Tap to reveal" prompt
   - User taps → card flips with haptic feedback
   - Photo revealed with photographer name & timestamp

5. **Progression**
   - Progress bar shows X of Y photos
   - Navigation arrows to go back/forward
   - "Skip All" button to jump to end
   - Can add emoji reactions (❤️ 😂 🔥)

6. **Completion**
   - Last photo revealed
   - Confetti animation 🎉
   - Celebration haptic pattern
   - "All Momentos Revealed!" overlay
   - "View Gallery" button to exit

7. **After Reveal**
   - Event card shows normal gallery icon
   - Can tap again to see photos in reveal mode
   - Photos remain accessible

---

## 🧪 Testing the Reveal System

### Without OAuth (Current State):

You can test the UI components in preview mode:

1. Open `RevealView.swift` in Xcode
2. Canvas preview shows the reveal experience
3. Can interact with cards, see animations

### With OAuth (Once Apple license approved):

1. **Create a test event:**
   - Release time: 1 hour from now
   - Take 3-5 photos during live window

2. **Manually trigger reveal (for testing):**
   ```sql
   -- In Supabase SQL Editor
   UPDATE events 
   SET is_revealed = true 
   WHERE join_code = 'YOUR_TEST_CODE';
   ```

3. **Test the reveal:**
   - Event card should glow
   - Tap card → opens RevealView
   - Tap each card to reveal
   - See confetti at end

---

## 🐛 Troubleshooting

### Cron job not running?
```sql
-- Check job status
SELECT * FROM cron.job_run_details 
ORDER BY start_time DESC 
LIMIT 10;
```

### Events not revealing automatically?
- Check Edge Function logs in Supabase Dashboard → Functions
- Manually trigger function with curl command above
- Verify events have `release_at` older than 24h

### Photos not loading in RevealView?
- Check photos table has `storage_path` field
- Verify storage bucket `momento-photos` exists
- Check RLS policies allow reading photos

---

## 📊 Database Schema Changes

**Added to `photos` table:**
```sql
reactions JSONB DEFAULT '{}'::jsonb
```

**Structure:**
```json
{
  "user_id_1": "❤️",
  "user_id_2": "😂",
  "user_id_3": "🔥"
}
```

---

## 🎯 What's Next

1. **Run the migration SQL** (Step 1 above)
2. **Setup cron job** (Step 2 above)
3. **Test function** (Step 3 above)
4. **Wait for Apple OAuth** (or use Google OAuth to test today)
5. **Create test event and reveal it!**

---

## 📝 Notes

- Edge Function checks every hour for events to reveal
- Reveal happens automatically at 24h mark
- Users don't need to do anything - it's magic! ✨
- Cron runs server-side, no client dependency
- Works even if app is closed

---

**Status:** Ready to test once OAuth is configured! 🚀

**Last Updated:** November 30, 2025

