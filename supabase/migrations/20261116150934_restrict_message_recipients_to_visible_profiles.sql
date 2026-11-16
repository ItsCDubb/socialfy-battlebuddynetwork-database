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

  INSERT INTO public.direct_conversations (created_by)
  VALUES (_current_user_id)
  RETURNING id INTO _conversation_id;

  INSERT INTO public.direct_conversation_participants (conversation_id, user_id)
  VALUES (_conversation_id, _current_user_id), (_conversation_id, _other_user_id);

  RETURN _conversation_id;
END;
$$;
