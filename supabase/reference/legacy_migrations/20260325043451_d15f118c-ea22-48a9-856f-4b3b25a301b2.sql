ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS privacy_phone text NOT NULL DEFAULT 'private',
  ADD COLUMN IF NOT EXISTS privacy_contact_email text NOT NULL DEFAULT 'private',
  ADD COLUMN IF NOT EXISTS privacy_location text NOT NULL DEFAULT 'members_only',
  ADD COLUMN IF NOT EXISTS privacy_branch text NOT NULL DEFAULT 'members_only',
  ADD COLUMN IF NOT EXISTS privacy_unit_name text NOT NULL DEFAULT 'members_only',
  ADD COLUMN IF NOT EXISTS privacy_bio text NOT NULL DEFAULT 'members_only';