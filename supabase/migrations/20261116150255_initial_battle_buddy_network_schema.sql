CREATE TYPE public.app_role AS ENUM ('admin', 'moderator', 'user');

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL DEFAULT 'Member',
  avatar_url text,
  branch text,
  unit_name text,
  bio text,
  phone text,
  contact_email text,
  location text,
  privacy_level text NOT NULL DEFAULT 'members_only'
    CHECK (privacy_level IN ('public', 'members_only', 'outer_circle', 'inner_circle', 'private')),
  privacy_branch text NOT NULL DEFAULT 'members_only'
    CHECK (privacy_branch IN ('public', 'members_only', 'outer_circle', 'inner_circle', 'private')),
  privacy_unit_name text NOT NULL DEFAULT 'members_only'
    CHECK (privacy_unit_name IN ('public', 'members_only', 'outer_circle', 'inner_circle', 'private')),
  privacy_bio text NOT NULL DEFAULT 'members_only'
    CHECK (privacy_bio IN ('public', 'members_only', 'outer_circle', 'inner_circle', 'private')),
  privacy_phone text NOT NULL DEFAULT 'private'
    CHECK (privacy_phone IN ('public', 'members_only', 'outer_circle', 'inner_circle', 'private')),
  privacy_contact_email text NOT NULL DEFAULT 'private'
    CHECK (privacy_contact_email IN ('public', 'members_only', 'outer_circle', 'inner_circle', 'private')),
  privacy_location text NOT NULL DEFAULT 'members_only'
    CHECK (privacy_location IN ('public', 'members_only', 'outer_circle', 'inner_circle', 'private')),
  last_seen_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL DEFAULT 'user',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_roles_user_role_unique UNIQUE (user_id, role)
);

CREATE TABLE public.groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (char_length(trim(name)) BETWEEN 3 AND 80),
  slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description text,
  mission text,
  is_public boolean NOT NULL DEFAULT true,
  is_system boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.group_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active' CHECK (status = 'active'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT group_memberships_group_user_unique UNIQUE (group_id, user_id)
);

CREATE TABLE public.friendships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  circle_level text NOT NULL DEFAULT 'outer' CHECK (circle_level IN ('inner', 'outer')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT friendships_not_self CHECK (requester_id <> addressee_id)
);

CREATE UNIQUE INDEX friendships_unique_pair
ON public.friendships (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));

CREATE TABLE public.posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  group_id uuid REFERENCES public.groups(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(trim(body)) BETWEEN 1 AND 10000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.post_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT post_likes_post_user_unique UNIQUE (post_id, user_id)
);

CREATE TABLE public.post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(trim(body)) BETWEEN 1 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.direct_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.direct_conversation_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  last_read_at timestamptz,
  CONSTRAINT direct_conversation_participants_unique UNIQUE (conversation_id, user_id)
);

CREATE TABLE public.direct_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(trim(body)) BETWEEN 1 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX profiles_display_name_idx ON public.profiles (display_name);
CREATE INDEX profiles_branch_idx ON public.profiles (branch);
CREATE INDEX groups_owner_id_idx ON public.groups (owner_id);
CREATE INDEX groups_public_created_at_idx ON public.groups (is_public, created_at DESC);
CREATE INDEX group_memberships_user_id_idx ON public.group_memberships (user_id);
CREATE INDEX group_memberships_group_id_idx ON public.group_memberships (group_id);
CREATE INDEX friendships_requester_id_idx ON public.friendships (requester_id);
CREATE INDEX friendships_addressee_id_idx ON public.friendships (addressee_id);
CREATE INDEX posts_group_created_at_idx ON public.posts (group_id, created_at DESC);
CREATE INDEX posts_author_id_idx ON public.posts (author_id);
CREATE INDEX post_likes_post_id_idx ON public.post_likes (post_id);
CREATE INDEX post_comments_post_created_at_idx ON public.post_comments (post_id, created_at);
CREATE INDEX direct_conversation_participants_user_id_idx ON public.direct_conversation_participants (user_id);
CREATE INDEX direct_conversation_participants_conversation_id_idx ON public.direct_conversation_participants (conversation_id);
CREATE INDEX direct_messages_conversation_created_at_idx ON public.direct_messages (conversation_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT _user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = _user_id AND role = _role
    );
$$;

CREATE OR REPLACE FUNCTION public.is_group_member(_group_id uuid, _user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT _user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.group_memberships
      WHERE group_id = _group_id AND user_id = _user_id AND status = 'active'
    );
$$;

CREATE OR REPLACE FUNCTION public.are_friends(_user_a uuid, _user_b uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT auth.uid() IN (_user_a, _user_b)
    AND EXISTS (
      SELECT 1 FROM public.friendships
      WHERE status = 'accepted'
        AND ((requester_id = _user_a AND addressee_id = _user_b)
          OR (requester_id = _user_b AND addressee_id = _user_a))
    );
$$;

CREATE OR REPLACE FUNCTION public.is_in_circle(_viewer_id uuid, _profile_owner_id uuid, _circle text DEFAULT 'outer')
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT _viewer_id = auth.uid()
    AND _circle IN ('outer', 'inner')
    AND EXISTS (
      SELECT 1 FROM public.friendships
      WHERE status = 'accepted'
        AND (
          (requester_id = _viewer_id AND addressee_id = _profile_owner_id)
          OR (requester_id = _profile_owner_id AND addressee_id = _viewer_id)
        )
        AND (_circle = 'outer' OR (_circle = 'inner' AND circle_level = 'inner'))
    );
$$;

CREATE OR REPLACE FUNCTION public.is_conversation_participant(_conversation_id uuid, _user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT _user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.direct_conversation_participants
      WHERE conversation_id = _conversation_id AND user_id = _user_id
    );
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
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = _other_user_id) THEN
    RAISE EXCEPTION 'Recipient not found';
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
      OR (auth.uid() IS NOT NULL AND p.privacy_branch = 'outer_circle' AND public.is_in_circle(auth.uid(), p.id, 'outer'))
      OR (auth.uid() IS NOT NULL AND p.privacy_branch = 'inner_circle' AND public.is_in_circle(auth.uid(), p.id, 'inner'))
      THEN p.branch ELSE NULL END,
    CASE WHEN p.id = auth.uid()
      OR p.privacy_bio = 'public'
      OR (auth.uid() IS NOT NULL AND p.privacy_bio = 'members_only')
      OR (auth.uid() IS NOT NULL AND p.privacy_bio = 'outer_circle' AND public.is_in_circle(auth.uid(), p.id, 'outer'))
      OR (auth.uid() IS NOT NULL AND p.privacy_bio = 'inner_circle' AND public.is_in_circle(auth.uid(), p.id, 'inner'))
      THEN p.bio ELSE NULL END,
    CASE WHEN p.id = auth.uid()
      OR p.privacy_location = 'public'
      OR (auth.uid() IS NOT NULL AND p.privacy_location = 'members_only')
      OR (auth.uid() IS NOT NULL AND p.privacy_location = 'outer_circle' AND public.is_in_circle(auth.uid(), p.id, 'outer'))
      OR (auth.uid() IS NOT NULL AND p.privacy_location = 'inner_circle' AND public.is_in_circle(auth.uid(), p.id, 'inner'))
      THEN p.location ELSE NULL END,
    p.avatar_url,
    p.last_seen_at,
    p.privacy_level
  FROM public.profiles p
  WHERE
    (p.id = auth.uid()
      OR p.privacy_level = 'public'
      OR (auth.uid() IS NOT NULL AND p.privacy_level = 'members_only')
      OR (auth.uid() IS NOT NULL AND p.privacy_level = 'outer_circle' AND public.is_in_circle(auth.uid(), p.id, 'outer'))
      OR (auth.uid() IS NOT NULL AND p.privacy_level = 'inner_circle' AND public.is_in_circle(auth.uid(), p.id, 'inner')))
    AND (_user_ids IS NULL OR p.id = ANY(_user_ids))
    AND (_search IS NULL OR p.display_name ILIKE '%' || _search || '%')
  ORDER BY p.display_name
  LIMIT GREATEST(1, LEAST(COALESCE(_limit, 100), 200));
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'display_name', ''), NULLIF(split_part(COALESCE(NEW.email, ''), '@', 1), ''), 'Member')
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'user')
  ON CONFLICT (user_id, role) DO NOTHING;

  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER groups_updated_at
BEFORE UPDATE ON public.groups
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER posts_updated_at
BEFORE UPDATE ON public.posts
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER direct_conversations_updated_at
BEFORE UPDATE ON public.direct_conversations
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER friendships_updated_at
BEFORE UPDATE ON public.friendships
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_select_self_or_admin ON public.profiles
FOR SELECT TO authenticated
USING (id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY profiles_update_self ON public.profiles
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

CREATE POLICY user_roles_select_self_or_admin ON public.user_roles
FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY groups_select_visible ON public.groups
FOR SELECT TO anon, authenticated
USING (
  is_public
  OR owner_id = auth.uid()
  OR public.is_group_member(id, auth.uid())
  OR public.has_role(auth.uid(), 'admin')
);

CREATE POLICY groups_insert_owner ON public.groups
FOR INSERT TO authenticated
WITH CHECK (owner_id = auth.uid() AND (NOT is_system OR public.has_role(auth.uid(), 'admin')));

CREATE POLICY groups_update_owner_or_admin ON public.groups
FOR UPDATE TO authenticated
USING (owner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'))
WITH CHECK (owner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY groups_delete_owner_or_admin ON public.groups
FOR DELETE TO authenticated
USING (owner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY group_memberships_select_related ON public.group_memberships
FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  OR public.is_group_member(group_id, auth.uid())
  OR EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND (g.is_public OR g.owner_id = auth.uid()))
  OR public.has_role(auth.uid(), 'admin')
);

CREATE POLICY group_memberships_insert_self_or_owner ON public.group_memberships
FOR INSERT TO authenticated
WITH CHECK (
  (user_id = auth.uid() AND EXISTS (
    SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.is_public
  ))
  OR EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.owner_id = auth.uid())
  OR public.has_role(auth.uid(), 'admin')
);

CREATE POLICY group_memberships_delete_self_owner_admin ON public.group_memberships
FOR DELETE TO authenticated
USING (
  user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.owner_id = auth.uid())
  OR public.has_role(auth.uid(), 'admin')
);

CREATE POLICY friendships_select_participant ON public.friendships
FOR SELECT TO authenticated
USING (requester_id = auth.uid() OR addressee_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY friendships_insert_requester ON public.friendships
FOR INSERT TO authenticated
WITH CHECK (requester_id = auth.uid() AND addressee_id <> auth.uid() AND status = 'pending');

CREATE POLICY friendships_respond_pending ON public.friendships
FOR UPDATE TO authenticated
USING (addressee_id = auth.uid() AND status = 'pending')
WITH CHECK (addressee_id = auth.uid() AND status IN ('accepted', 'rejected'));

CREATE POLICY friendships_update_circle ON public.friendships
FOR UPDATE TO authenticated
USING (status = 'accepted' AND (requester_id = auth.uid() OR addressee_id = auth.uid()))
WITH CHECK (status = 'accepted' AND (requester_id = auth.uid() OR addressee_id = auth.uid()));

CREATE POLICY friendships_delete_participant ON public.friendships
FOR DELETE TO authenticated
USING (requester_id = auth.uid() OR addressee_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY posts_select_accessible ON public.posts
FOR SELECT TO authenticated
USING (
  group_id IS NULL
  OR EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.is_public)
  OR public.is_group_member(group_id, auth.uid())
  OR public.has_role(auth.uid(), 'admin')
);

CREATE POLICY posts_insert_author ON public.posts
FOR INSERT TO authenticated
WITH CHECK (
  author_id = auth.uid()
  AND (group_id IS NULL OR public.is_group_member(group_id, auth.uid()))
);

CREATE POLICY posts_update_author_or_admin ON public.posts
FOR UPDATE TO authenticated
USING (author_id = auth.uid() OR public.has_role(auth.uid(), 'admin'))
WITH CHECK (author_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY posts_delete_author_or_admin ON public.posts
FOR DELETE TO authenticated
USING (author_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY post_likes_select_accessible ON public.post_likes
FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id));

CREATE POLICY post_likes_insert_self ON public.post_likes
FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id));

CREATE POLICY post_likes_delete_self ON public.post_likes
FOR DELETE TO authenticated
USING (user_id = auth.uid());

CREATE POLICY post_comments_select_accessible ON public.post_comments
FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id));

CREATE POLICY post_comments_insert_self ON public.post_comments
FOR INSERT TO authenticated
WITH CHECK (author_id = auth.uid() AND EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id));

CREATE POLICY post_comments_delete_self_or_admin ON public.post_comments
FOR DELETE TO authenticated
USING (author_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY conversations_select_participant ON public.direct_conversations
FOR SELECT TO authenticated
USING (public.is_conversation_participant(id, auth.uid()));

CREATE POLICY participants_select_conversation ON public.direct_conversation_participants
FOR SELECT TO authenticated
USING (public.is_conversation_participant(conversation_id, auth.uid()));

CREATE POLICY participants_update_own_read_state ON public.direct_conversation_participants
FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY messages_select_participant ON public.direct_messages
FOR SELECT TO authenticated
USING (public.is_conversation_participant(conversation_id, auth.uid()));

CREATE POLICY messages_insert_sender ON public.direct_messages
FOR INSERT TO authenticated
WITH CHECK (sender_id = auth.uid() AND public.is_conversation_participant(conversation_id, auth.uid()));

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT ON public.groups TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.groups TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.group_memberships TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.friendships TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.posts TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.post_likes TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.post_comments TO authenticated;
GRANT SELECT ON public.direct_conversations TO authenticated;
GRANT SELECT, UPDATE ON public.direct_conversation_participants TO authenticated;
GRANT SELECT, INSERT ON public.direct_messages TO authenticated;
GRANT SELECT ON public.user_roles TO authenticated;

GRANT UPDATE (last_read_at) ON public.direct_conversation_participants TO authenticated;
GRANT UPDATE (status, circle_level) ON public.friendships TO authenticated;

REVOKE ALL ON FUNCTION public.update_updated_at_column() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_role(uuid, public.app_role) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_group_member(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.are_friends(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_in_circle(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_conversation_participant(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_or_create_direct_conversation(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_visible_profiles(uuid[], text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_group_member(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.are_friends(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_in_circle(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_conversation_participant(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_direct_conversation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_visible_profiles(uuid[], text, integer) TO anon, authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'posts'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'direct_messages'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.direct_messages;
    END IF;
  END IF;
END;
$$;
