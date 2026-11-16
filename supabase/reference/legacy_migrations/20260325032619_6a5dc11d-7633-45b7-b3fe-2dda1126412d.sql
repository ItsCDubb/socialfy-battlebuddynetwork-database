
-- Add privacy_level to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS privacy_level text NOT NULL DEFAULT 'members_only';

-- Add is_system flag to groups
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS is_system boolean NOT NULL DEFAULT false;

-- Drop FK on owner_id (references auth.users which we shouldn't FK to)
ALTER TABLE public.groups DROP CONSTRAINT IF EXISTS groups_owner_id_fkey;

-- Update profiles RLS for privacy
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;

CREATE POLICY "Users can view their own profile"
  ON public.profiles FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Members can view members_only profiles"
  ON public.profiles FOR SELECT TO authenticated
  USING (privacy_level = 'members_only');

CREATE POLICY "Anyone can view public profiles"
  ON public.profiles FOR SELECT TO anon, authenticated
  USING (privacy_level = 'public');

-- Seed 12 branch groups
INSERT INTO public.groups (owner_id, name, slug, description, mission, is_public, is_system) VALUES
  ('00000000-0000-0000-0000-000000000000', 'Active Duty Army', 'active-duty-army', 'For currently serving Army soldiers.', 'Connect, support, and strengthen the bond between those currently serving in the U.S. Army.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Army Veterans', 'army-veterans', 'For those who have served in the U.S. Army.', 'Honor your service and stay connected with fellow Army veterans.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Active Duty Navy', 'active-duty-navy', 'For currently serving Navy sailors.', 'A community for active duty Navy personnel to connect and support one another.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Navy Veterans', 'navy-veterans', 'For those who have served in the U.S. Navy.', 'Stay anchored to your Navy family after service.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Active Duty Air Force', 'active-duty-air-force', 'For currently serving Air Force airmen.', 'Connect with fellow airmen serving in the U.S. Air Force.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Air Force Veterans', 'air-force-veterans', 'For those who have served in the U.S. Air Force.', 'Keep the bond alive with fellow Air Force veterans.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Active Duty Marines', 'active-duty-marines', 'For currently serving Marines.', 'Semper Fi — connect with Marines currently serving.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Marine Veterans', 'marine-veterans', 'For those who have served in the U.S. Marine Corps.', 'Once a Marine, always a Marine. Stay connected.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Active Duty Coast Guard', 'active-duty-coast-guard', 'For currently serving Coast Guard members.', 'A community for active duty Coast Guard to connect and support each other.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Coast Guard Veterans', 'coast-guard-veterans', 'For those who have served in the U.S. Coast Guard.', 'Stay connected with your Coast Guard family after service.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Active Duty Space Force', 'active-duty-space-force', 'For currently serving Space Force guardians.', 'Connect with fellow guardians serving in the U.S. Space Force.', true, true),
  ('00000000-0000-0000-0000-000000000000', 'Space Force Veterans', 'space-force-veterans', 'For those who have served in the U.S. Space Force.', 'Stay connected with your Space Force family after service.', true, true);
