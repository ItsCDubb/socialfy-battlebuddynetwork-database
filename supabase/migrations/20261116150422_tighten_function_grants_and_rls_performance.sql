REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated, PUBLIC;
DO $
BEGIN
  IF to_regprocedure('public.rls_auto_enable()') IS NOT NULL THEN
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM anon, authenticated, PUBLIC';
  END IF;
END;
$;

REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_group_member(uuid, uuid) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.are_friends(uuid, uuid) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_in_circle(uuid, uuid, text) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_conversation_participant(uuid, uuid) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_or_create_direct_conversation(uuid) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_visible_profiles(uuid[], text, integer) FROM anon, authenticated, PUBLIC;

GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_group_member(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.are_friends(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_in_circle(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_conversation_participant(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_direct_conversation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_visible_profiles(uuid[], text, integer) TO anon, authenticated;

CREATE INDEX direct_conversations_created_by_idx ON public.direct_conversations (created_by);
CREATE INDEX direct_messages_sender_id_idx ON public.direct_messages (sender_id);
CREATE INDEX post_comments_author_id_idx ON public.post_comments (author_id);
CREATE INDEX post_likes_user_id_idx ON public.post_likes (user_id);

DROP POLICY profiles_select_self_or_admin ON public.profiles;
CREATE POLICY profiles_select_self_or_admin ON public.profiles
FOR SELECT TO authenticated
USING (id = (SELECT auth.uid()) OR public.has_role((SELECT auth.uid()), 'admin'));

DROP POLICY profiles_update_self ON public.profiles;
CREATE POLICY profiles_update_self ON public.profiles
FOR UPDATE TO authenticated
USING (id = (SELECT auth.uid()))
WITH CHECK (id = (SELECT auth.uid()));

DROP POLICY user_roles_select_self_or_admin ON public.user_roles;
CREATE POLICY user_roles_select_self_or_admin ON public.user_roles
FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()) OR public.has_role((SELECT auth.uid()), 'admin'));

DROP POLICY groups_select_visible ON public.groups;
CREATE POLICY groups_select_visible ON public.groups
FOR SELECT TO anon, authenticated
USING (
  is_public
  OR owner_id = (SELECT auth.uid())
  OR public.is_group_member(id, (SELECT auth.uid()))
  OR public.has_role((SELECT auth.uid()), 'admin')
);

DROP POLICY groups_insert_owner ON public.groups;
CREATE POLICY groups_insert_owner ON public.groups
FOR INSERT TO authenticated
WITH CHECK (
  owner_id = (SELECT auth.uid())
  AND (NOT is_system OR public.has_role((SELECT auth.uid()), 'admin'))
);

DROP POLICY groups_update_owner_or_admin ON public.groups;
CREATE POLICY groups_update_owner_or_admin ON public.groups
FOR UPDATE TO authenticated
USING (owner_id = (SELECT auth.uid()) OR public.has_role((SELECT auth.uid()), 'admin'))
WITH CHECK (owner_id = (SELECT auth.uid()) OR public.has_role((SELECT auth.uid()), 'admin'));

DROP POLICY groups_delete_owner_or_admin ON public.groups;
CREATE POLICY groups_delete_owner_or_admin ON public.groups
FOR DELETE TO authenticated
USING (owner_id = (SELECT auth.uid()) OR public.has_role((SELECT auth.uid()), 'admin'));

DROP POLICY group_memberships_select_related ON public.group_memberships;
CREATE POLICY group_memberships_select_related ON public.group_memberships
FOR SELECT TO authenticated
USING (
  user_id = (SELECT auth.uid())
  OR public.is_group_member(group_id, (SELECT auth.uid()))
  OR EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND (g.is_public OR g.owner_id = (SELECT auth.uid())))
  OR public.has_role((SELECT auth.uid()), 'admin')
);

DROP POLICY group_memberships_insert_self_or_owner ON public.group_memberships;
CREATE POLICY group_memberships_insert_self_or_owner ON public.group_memberships
FOR INSERT TO authenticated
WITH CHECK (
  (user_id = (SELECT auth.uid()) AND EXISTS (
    SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.is_public
  ))
  OR EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.owner_id = (SELECT auth.uid()))
  OR public.has_role((SELECT auth.uid()), 'admin')
);

DROP POLICY group_memberships_delete_self_owner_admin ON public.group_memberships;
CREATE POLICY group_memberships_delete_self_owner_admin ON public.group_memberships
FOR DELETE TO authenticated
USING (
  user_id = (SELECT auth.uid())
  OR EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.owner_id = (SELECT auth.uid()))
  OR public.has_role((SELECT auth.uid()), 'admin')
);

DROP POLICY friendships_select_participant ON public.friendships;
CREATE POLICY friendships_select_participant ON public.friendships
FOR SELECT TO authenticated
USING (
  requester_id = (SELECT auth.uid())
  OR addressee_id = (SELECT auth.uid())
  OR public.has_role((SELECT auth.uid()), 'admin')
);

DROP POLICY friendships_insert_requester ON public.friendships;
CREATE POLICY friendships_insert_requester ON public.friendships
FOR INSERT TO authenticated
WITH CHECK (
  requester_id = (SELECT auth.uid())
  AND addressee_id <> (SELECT auth.uid())
  AND status = 'pending'
);

DROP POLICY friendships_respond_pending ON public.friendships;
DROP POLICY friendships_update_circle ON public.friendships;
CREATE POLICY friendships_update_participant ON public.friendships
FOR UPDATE TO authenticated
USING (
  (addressee_id = (SELECT auth.uid()) AND status = 'pending')
  OR (status = 'accepted' AND (
    requester_id = (SELECT auth.uid()) OR addressee_id = (SELECT auth.uid())
  ))
)
WITH CHECK (
  (addressee_id = (SELECT auth.uid()) AND status IN ('accepted', 'rejected'))
  OR (status = 'accepted' AND (
    requester_id = (SELECT auth.uid()) OR addressee_id = (SELECT auth.uid())
  ))
);

DROP POLICY friendships_delete_participant ON public.friendships;
CREATE POLICY friendships_delete_participant ON public.friendships
FOR DELETE TO authenticated
USING (
  requester_id = (SELECT auth.uid())
  OR addressee_id = (SELECT auth.uid())
  OR public.has_role((SELECT auth.uid()), 'admin')
);

DROP POLICY posts_select_accessible ON public.posts;
CREATE POLICY posts_select_accessible ON public.posts
FOR SELECT TO authenticated
USING (
  group_id IS NULL
  OR EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.is_public)
  OR public.is_group_member(group_id, (SELECT auth.uid()))
  OR public.has_role((SELECT auth.uid()), 'admin')
);

DROP POLICY posts_insert_author ON public.posts;
CREATE POLICY posts_insert_author ON public.posts
FOR INSERT TO authenticated
WITH CHECK (
  author_id = (SELECT auth.uid())
  AND (group_id IS NULL OR public.is_group_member(group_id, (SELECT auth.uid())))
);

DROP POLICY posts_update_author_or_admin ON public.posts;
CREATE POLICY posts_update_author_or_admin ON public.posts
FOR UPDATE TO authenticated
USING (author_id = (SELECT auth.uid()) OR public.has_role((SELECT auth.uid()), 'admin'))
WITH CHECK (author_id = (SELECT auth.uid()) OR public.has_role((SELECT auth.uid()), 'admin'));

DROP POLICY posts_delete_author_or_admin ON public.posts;
CREATE POLICY posts_delete_author_or_admin ON public.posts
FOR DELETE TO authenticated
USING (author_id = (SELECT auth.uid()) OR public.has_role((SELECT auth.uid()), 'admin'));

DROP POLICY post_likes_select_accessible ON public.post_likes;
CREATE POLICY post_likes_select_accessible ON public.post_likes
FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id));

DROP POLICY post_likes_insert_self ON public.post_likes;
CREATE POLICY post_likes_insert_self ON public.post_likes
FOR INSERT TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id)
);

DROP POLICY post_likes_delete_self ON public.post_likes;
CREATE POLICY post_likes_delete_self ON public.post_likes
FOR DELETE TO authenticated
USING (user_id = (SELECT auth.uid()));

DROP POLICY post_comments_select_accessible ON public.post_comments;
CREATE POLICY post_comments_select_accessible ON public.post_comments
FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id));

DROP POLICY post_comments_insert_self ON public.post_comments;
CREATE POLICY post_comments_insert_self ON public.post_comments
FOR INSERT TO authenticated
WITH CHECK (
  author_id = (SELECT auth.uid())
  AND EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id)
);

DROP POLICY post_comments_delete_self_or_admin ON public.post_comments;
CREATE POLICY post_comments_delete_self_or_admin ON public.post_comments
FOR DELETE TO authenticated
USING (author_id = (SELECT auth.uid()) OR public.has_role((SELECT auth.uid()), 'admin'));

DROP POLICY conversations_select_participant ON public.direct_conversations;
CREATE POLICY conversations_select_participant ON public.direct_conversations
FOR SELECT TO authenticated
USING (public.is_conversation_participant(id, (SELECT auth.uid())));

DROP POLICY participants_select_conversation ON public.direct_conversation_participants;
CREATE POLICY participants_select_conversation ON public.direct_conversation_participants
FOR SELECT TO authenticated
USING (public.is_conversation_participant(conversation_id, (SELECT auth.uid())));

DROP POLICY participants_update_own_read_state ON public.direct_conversation_participants;
CREATE POLICY participants_update_own_read_state ON public.direct_conversation_participants
FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY messages_select_participant ON public.direct_messages;
CREATE POLICY messages_select_participant ON public.direct_messages
FOR SELECT TO authenticated
USING (public.is_conversation_participant(conversation_id, (SELECT auth.uid())));

DROP POLICY messages_insert_sender ON public.direct_messages;
CREATE POLICY messages_insert_sender ON public.direct_messages
FOR INSERT TO authenticated
WITH CHECK (
  sender_id = (SELECT auth.uid())
  AND public.is_conversation_participant(conversation_id, (SELECT auth.uid()))
);
