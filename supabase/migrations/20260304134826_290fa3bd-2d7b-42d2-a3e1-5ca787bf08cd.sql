-- Create role enum
DO $$ BEGIN
  CREATE TYPE public.app_role AS ENUM ('admin', 'moderator', 'user');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Shared updated_at trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  branch TEXT,
  unit_name TEXT,
  bio TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- User roles table
CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  );
$$;

DROP POLICY IF EXISTS "Users can view their own roles" ON public.user_roles;
CREATE POLICY "Users can view their own roles"
ON public.user_roles
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Groups table
CREATE TABLE IF NOT EXISTS public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  mission TEXT,
  is_public BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT groups_name_length CHECK (char_length(name) >= 3),
  CONSTRAINT groups_slug_format CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

-- Group memberships table
CREATE TABLE IF NOT EXISTS public.group_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (group_id, user_id),
  CONSTRAINT group_memberships_status_check CHECK (status IN ('active'))
);

ALTER TABLE public.group_memberships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view public groups" ON public.groups;
CREATE POLICY "Authenticated users can view public groups"
ON public.groups
FOR SELECT
TO anon, authenticated
USING (
  is_public
  OR auth.uid() = owner_id
  OR EXISTS (
    SELECT 1 FROM public.group_memberships gm
    WHERE gm.group_id = groups.id AND gm.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Users can create groups" ON public.groups;
CREATE POLICY "Users can create groups"
ON public.groups
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can update their groups" ON public.groups;
CREATE POLICY "Owners can update their groups"
ON public.groups
FOR UPDATE
TO authenticated
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can delete their groups" ON public.groups;
CREATE POLICY "Owners can delete their groups"
ON public.groups
FOR DELETE
TO authenticated
USING (auth.uid() = owner_id OR public.has_role(auth.uid(), 'admin'));

DROP TRIGGER IF EXISTS update_groups_updated_at ON public.groups;
CREATE TRIGGER update_groups_updated_at
BEFORE UPDATE ON public.groups
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

DROP POLICY IF EXISTS "Users can view memberships they belong to" ON public.group_memberships;
CREATE POLICY "Users can view memberships they belong to"
ON public.group_memberships
FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.groups g
    WHERE g.id = group_memberships.group_id
      AND (g.owner_id = auth.uid() OR g.is_public)
  )
);

DROP POLICY IF EXISTS "Users can join groups as themselves" ON public.group_memberships;
CREATE POLICY "Users can join groups as themselves"
ON public.group_memberships
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (
    SELECT 1 FROM public.groups g
    WHERE g.id = group_memberships.group_id
      AND g.is_public = true
  )
);

DROP POLICY IF EXISTS "Owners can add members" ON public.group_memberships;
CREATE POLICY "Owners can add members"
ON public.group_memberships
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.groups g
    WHERE g.id = group_memberships.group_id
      AND g.owner_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Users can leave or owners can remove memberships" ON public.group_memberships;
CREATE POLICY "Users can leave or owners can remove memberships"
ON public.group_memberships
FOR DELETE
TO authenticated
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.groups g
    WHERE g.id = group_memberships.group_id
      AND g.owner_id = auth.uid()
  )
);

-- Auto-create profile and default role on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'display_name', split_part(NEW.email, '@', 1), 'Member')
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'user')
  ON CONFLICT (user_id, role) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_groups_owner_id ON public.groups(owner_id);
CREATE INDEX IF NOT EXISTS idx_groups_public_created_at ON public.groups(is_public, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_group_memberships_group_id ON public.group_memberships(group_id);
CREATE INDEX IF NOT EXISTS idx_group_memberships_user_id ON public.group_memberships(user_id);