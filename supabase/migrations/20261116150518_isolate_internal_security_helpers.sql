CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO authenticated;

ALTER FUNCTION public.update_updated_at_column() SET SCHEMA private;
ALTER FUNCTION public.handle_new_user() SET SCHEMA private;
ALTER FUNCTION public.has_role(uuid, public.app_role) SET SCHEMA private;
ALTER FUNCTION public.is_group_member(uuid, uuid) SET SCHEMA private;
ALTER FUNCTION public.are_friends(uuid, uuid) SET SCHEMA private;
ALTER FUNCTION public.is_in_circle(uuid, uuid, text) SET SCHEMA private;
ALTER FUNCTION public.is_conversation_participant(uuid, uuid) SET SCHEMA private;

REVOKE ALL ON FUNCTION private.update_updated_at_column() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.has_role(uuid, public.app_role) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_group_member(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.are_friends(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_in_circle(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_conversation_participant(uuid, uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.has_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_group_member(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_conversation_participant(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_visible_profiles(
  _user_ids uuid[] DEFAULT NULL,
  _search text DEFAULT NULL,
  _limit integer DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  display_name text,
  branch text,
  bio text,
  location text,
  avatar_url text,
  last_seen_at timestamptz,
  privacy_level text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p.id,
    p.display_name,
    CASE WHEN p.id = auth.uid()
      OR p.privacy_branch = 'public'
      OR (auth.uid() IS NOT NULL AND p.privacy_branch = 'members_only')
      OR (auth.uid() IS NOT NULL AND p.privacy_branch = 'outer_circle' AND private.is_in_circle(auth.uid(), p.id, 'outer'))
      OR (auth.uid() IS NOT NULL AND p.privacy_branch = 'inner_circle' AND private.is_in_circle(auth.uid(), p.id, 'inner'))
      THEN p.branch ELSE NULL END,
    CASE WHEN p.id = auth.uid()
      OR p.privacy_bio = 'public'
      OR (auth.uid() IS NOT NULL AND p.privacy_bio = 'members_only')
      OR (auth.uid() IS NOT NULL AND p.privacy_bio = 'outer_circle' AND private.is_in_circle(auth.uid(), p.id, 'outer'))
      OR (auth.uid() IS NOT NULL AND p.privacy_bio = 'inner_circle' AND private.is_in_circle(auth.uid(), p.id, 'inner'))
      THEN p.bio ELSE NULL END,
    CASE WHEN p.id = auth.uid()
      OR p.privacy_location = 'public'
      OR (auth.uid() IS NOT NULL AND p.privacy_location = 'members_only')
      OR (auth.uid() IS NOT NULL AND p.privacy_location = 'outer_circle' AND private.is_in_circle(auth.uid(), p.id, 'outer'))
      OR (auth.uid() IS NOT NULL AND p.privacy_location = 'inner_circle' AND private.is_in_circle(auth.uid(), p.id, 'inner'))
      THEN p.location ELSE NULL END,
    p.avatar_url,
    p.last_seen_at,
    p.privacy_level
  FROM public.profiles p
  WHERE
    (p.id = auth.uid()
      OR p.privacy_level = 'public'
      OR (auth.uid() IS NOT NULL AND p.privacy_level = 'members_only')
      OR (auth.uid() IS NOT NULL AND p.privacy_level = 'outer_circle' AND private.is_in_circle(auth.uid(), p.id, 'outer'))
      OR (auth.uid() IS NOT NULL AND p.privacy_level = 'inner_circle' AND private.is_in_circle(auth.uid(), p.id, 'inner')))
    AND (_user_ids IS NULL OR p.id = ANY(_user_ids))
    AND (_search IS NULL OR p.display_name ILIKE '%' || _search || '%')
  ORDER BY p.display_name
  LIMIT GREATEST(1, LEAST(COALESCE(_limit, 100), 200));
$$;

REVOKE ALL ON FUNCTION public.get_visible_profiles(uuid[], text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_visible_profiles(uuid[], text, integer) TO anon, authenticated;
