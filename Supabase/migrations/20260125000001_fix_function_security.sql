-- Fix Function Security: Set immutable search_path
-- This prevents privilege escalation attacks via search_path manipulation

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = '';

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'user' || floor(random() * 10000)::text),
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = '';

CREATE OR REPLACE FUNCTION public.update_event_member_count()
RETURNS TRIGGER AS $$
DECLARE
  target_event_id UUID;
BEGIN
  target_event_id := COALESCE(NEW.event_id, OLD.event_id);
  UPDATE public.events
  SET member_count = (SELECT COUNT(*) FROM public.event_members WHERE event_id = target_event_id)
  WHERE id = target_event_id;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
SET search_path = '';

CREATE OR REPLACE FUNCTION public.update_event_photo_count()
RETURNS TRIGGER AS $$
DECLARE
  target_event_id UUID;
BEGIN
  target_event_id := COALESCE(NEW.event_id, OLD.event_id);
  UPDATE public.events
  SET photo_count = (SELECT COUNT(*) FROM public.photos WHERE event_id = target_event_id)
  WHERE id = target_event_id;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
SET search_path = '';
