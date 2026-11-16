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
    (
      p.id = auth.uid()
      OR p.privacy_level = 'public'
      OR (auth.uid() IS NOT NULL AND p.privacy_level = 'members_only')
      OR (auth.uid() IS NOT NULL AND p.privacy_level = 'outer_circle' AND private.is_in_circle(auth.uid(), p.id, 'outer'))
      OR (auth.uid() IS NOT NULL AND p.privacy_level = 'inner_circle' AND private.is_in_circle(auth.uid(), p.id, 'inner'))
      OR (
        auth.uid() IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.direct_conversation_participants mine
          JOIN public.direct_conversation_participants theirs
            ON theirs.conversation_id = mine.conversation_id
          WHERE mine.user_id = auth.uid()
            AND theirs.user_id = p.id
        )
      )
    )
    AND (_user_ids IS NULL OR p.id = ANY(_user_ids))
    AND (_search IS NULL OR p.display_name ILIKE '%' || _search || '%')
  ORDER BY p.display_name
  LIMIT GREATEST(1, LEAST(COALESCE(_limit, 100), 200));
$$;

CREATE OR REPLACE FUNCTION public.get_or_create_direct_conversation(_other_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _current_user_id uuid := auth.uid();
  _conversation_id uuid;
  _pair_key text;
BEGIN
  IF _current_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF _other_user_id IS NULL OR _other_user_id = _current_user_id THEN
    RAISE EXCEPTION 'A different recipient is required';
  END IF;

  _pair_key := LEAST(_current_user_id::text, _other_user_id::text) || ':' ||
               GREATEST(_current_user_id::text, _other_user_id::text);
  PERFORM pg_advisory_xact_lock(hashtextextended(_pair_key, 0));

  SELECT c.id INTO _conversation_id
  FROM public.direct_conversations c
  JOIN public.direct_conversation_participants p1
    ON p1.conversation_id = c.id AND p1.user_id = _current_user_id
  JOIN public.direct_conversation_participants p2
    ON p2.conversation_id = c.id AND p2.user_id = _other_user_id
  WHERE (SELECT count(*) FROM public.direct_conversation_participants px
         WHERE px.conversation_id = c.id) = 2
  ORDER BY c.created_at
  LIMIT 1;

  IF _conversation_id IS NOT NULL THEN
    RETURN _conversation_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = _other_user_id
      AND (
        p.privacy_level = 'public'
        OR p.privacy_level = 'members_only'
        OR (p.privacy_level = 'outer_circle' AND private.is_in_circle(_current_user_id, p.id, 'outer'))
        OR (p.privacy_level = 'inner_circle' AND private.is_in_circle(_current_user_id, p.id, 'inner'))
      )
  ) THEN
    RAISE EXCEPTION 'Recipient is not available';
  END IF;

  INSERT INTO public.direct_conversations (created_by)
  VALUES (_current_user_id)
  RETURNING id INTO _conversation_id;

  INSERT INTO public.direct_conversation_participants (conversation_id, user_id)
  VALUES (_conversation_id, _current_user_id), (_conversation_id, _other_user_id);

  RETURN _conversation_id;
END;
$$;
