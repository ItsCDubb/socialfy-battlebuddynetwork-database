DROP POLICY groups_select_visible ON public.groups;

CREATE POLICY groups_public_select ON public.groups
FOR SELECT TO anon
USING (is_public);

CREATE POLICY groups_select_visible ON public.groups
FOR SELECT TO authenticated
USING (
  is_public
  OR owner_id = (SELECT auth.uid())
  OR private.is_group_member(id, (SELECT auth.uid()))
  OR private.has_role((SELECT auth.uid()), 'admin')
);
