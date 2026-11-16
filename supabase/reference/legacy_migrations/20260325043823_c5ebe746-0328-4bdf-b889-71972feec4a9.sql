-- Add circle_level to friendships to distinguish inner vs outer
ALTER TABLE public.friendships ADD COLUMN IF NOT EXISTS circle_level text NOT NULL DEFAULT 'outer';

-- Update the are_friends function to also support circle checks
CREATE OR REPLACE FUNCTION public.is_in_circle(_viewer_id uuid, _profile_owner_id uuid, _circle text DEFAULT 'outer')
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.friendships
    WHERE status = 'accepted'
      AND (
        (requester_id = _viewer_id AND addressee_id = _profile_owner_id)
        OR (requester_id = _profile_owner_id AND addressee_id = _viewer_id)
      )
      AND (
        _circle = 'outer'
        OR (_circle = 'inner' AND circle_level = 'inner')
      )
  );
$$;