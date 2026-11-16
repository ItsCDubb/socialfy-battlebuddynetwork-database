REVOKE UPDATE ON TABLE public.direct_conversation_participants FROM authenticated;
GRANT UPDATE (last_read_at) ON TABLE public.direct_conversation_participants TO authenticated;

REVOKE UPDATE ON TABLE public.friendships FROM authenticated;
GRANT UPDATE (status, circle_level) ON TABLE public.friendships TO authenticated;

DROP POLICY groups_update_owner_or_admin ON public.groups;
CREATE POLICY groups_update_owner_or_admin ON public.groups
FOR UPDATE TO authenticated
USING (
  owner_id = (SELECT auth.uid())
  OR private.has_role((SELECT auth.uid()), 'admin')
)
WITH CHECK (
  (owner_id = (SELECT auth.uid()) AND NOT is_system)
  OR private.has_role((SELECT auth.uid()), 'admin')
);

DROP POLICY posts_update_author_or_admin ON public.posts;
CREATE POLICY posts_update_author_or_admin ON public.posts
FOR UPDATE TO authenticated
USING (
  author_id = (SELECT auth.uid())
  OR private.has_role((SELECT auth.uid()), 'admin')
)
WITH CHECK (
  (
    author_id = (SELECT auth.uid())
    AND (group_id IS NULL OR private.is_group_member(group_id, (SELECT auth.uid())))
  )
  OR private.has_role((SELECT auth.uid()), 'admin')
);
