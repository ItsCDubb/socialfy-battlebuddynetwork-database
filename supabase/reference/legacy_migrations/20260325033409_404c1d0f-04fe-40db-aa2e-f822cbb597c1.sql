
-- Posts table
CREATE TABLE public.posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL,
  group_id uuid REFERENCES public.groups(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can see posts in public groups or groups they belong to
CREATE POLICY "View posts in accessible groups" ON public.posts
  FOR SELECT TO authenticated
  USING (
    group_id IS NULL
    OR EXISTS (SELECT 1 FROM public.groups g WHERE g.id = group_id AND g.is_public)
    OR EXISTS (SELECT 1 FROM public.group_memberships gm WHERE gm.group_id = posts.group_id AND gm.user_id = auth.uid())
  );

CREATE POLICY "Users can create posts" ON public.posts
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = author_id
    AND (
      group_id IS NULL
      OR EXISTS (SELECT 1 FROM public.group_memberships gm WHERE gm.group_id = posts.group_id AND gm.user_id = auth.uid())
    )
  );

CREATE POLICY "Users can update their own posts" ON public.posts
  FOR UPDATE TO authenticated
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can delete their own posts" ON public.posts
  FOR DELETE TO authenticated
  USING (auth.uid() = author_id);

-- Post likes
CREATE TABLE public.post_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "View likes" ON public.post_likes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can like" ON public.post_likes
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unlike" ON public.post_likes
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Comments
CREATE TABLE public.post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  author_id uuid NOT NULL,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "View comments" ON public.post_comments
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can comment" ON public.post_comments
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can delete their comments" ON public.post_comments
  FOR DELETE TO authenticated
  USING (auth.uid() = author_id);

-- Indexes
CREATE INDEX idx_posts_group ON public.posts(group_id, created_at DESC);
CREATE INDEX idx_posts_author ON public.posts(author_id);
CREATE INDEX idx_post_likes_post ON public.post_likes(post_id);
CREATE INDEX idx_post_comments_post ON public.post_comments(post_id, created_at);

-- Realtime for posts
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
