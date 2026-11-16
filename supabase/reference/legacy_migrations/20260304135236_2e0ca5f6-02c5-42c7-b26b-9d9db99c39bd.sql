-- Direct message conversations
CREATE TABLE public.direct_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.direct_conversations ENABLE ROW LEVEL SECURITY;

-- Conversation participants
CREATE TABLE public.direct_conversation_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_read_at TIMESTAMPTZ,
  UNIQUE (conversation_id, user_id)
);

ALTER TABLE public.direct_conversation_participants ENABLE ROW LEVEL SECURITY;

-- Helper functions to avoid recursive RLS checks
CREATE OR REPLACE FUNCTION public.is_conversation_participant(_conversation_id UUID, _user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.direct_conversation_participants
    WHERE conversation_id = _conversation_id
      AND user_id = _user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.get_or_create_direct_conversation(_other_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _current_user_id UUID := auth.uid();
  _conversation_id UUID;
BEGIN
  IF _current_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF _other_user_id IS NULL OR _other_user_id = _current_user_id THEN
    RAISE EXCEPTION 'A different recipient is required';
  END IF;

  SELECT p1.conversation_id
  INTO _conversation_id
  FROM public.direct_conversation_participants p1
  JOIN public.direct_conversation_participants p2
    ON p1.conversation_id = p2.conversation_id
  WHERE p1.user_id = _current_user_id
    AND p2.user_id = _other_user_id
  GROUP BY p1.conversation_id
  HAVING COUNT(*) = 2
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

-- Messages
CREATE TABLE public.direct_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT direct_messages_body_length CHECK (char_length(trim(body)) BETWEEN 1 AND 2000)
);

ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

-- Timestamp trigger
DROP TRIGGER IF EXISTS update_direct_conversations_updated_at ON public.direct_conversations;
CREATE TRIGGER update_direct_conversations_updated_at
BEFORE UPDATE ON public.direct_conversations
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Policies: conversations
CREATE POLICY "Participants can view conversations"
ON public.direct_conversations
FOR SELECT
TO authenticated
USING (public.is_conversation_participant(id, auth.uid()));

CREATE POLICY "Authenticated users can create conversations"
ON public.direct_conversations
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Participants can update conversation timestamps"
ON public.direct_conversations
FOR UPDATE
TO authenticated
USING (public.is_conversation_participant(id, auth.uid()))
WITH CHECK (public.is_conversation_participant(id, auth.uid()));

-- Policies: participants
CREATE POLICY "Participants can view conversation participants"
ON public.direct_conversation_participants
FOR SELECT
TO authenticated
USING (public.is_conversation_participant(conversation_id, auth.uid()));

CREATE POLICY "Users can add themselves as participants"
ON public.direct_conversation_participants
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Participants can update their own read state"
ON public.direct_conversation_participants
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policies: messages
CREATE POLICY "Participants can view messages"
ON public.direct_messages
FOR SELECT
TO authenticated
USING (public.is_conversation_participant(conversation_id, auth.uid()));

CREATE POLICY "Participants can send messages"
ON public.direct_messages
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = sender_id
  AND public.is_conversation_participant(conversation_id, auth.uid())
);

-- Helpful indexes
CREATE INDEX idx_direct_conversation_participants_user_id ON public.direct_conversation_participants(user_id);
CREATE INDEX idx_direct_conversation_participants_conversation_id ON public.direct_conversation_participants(conversation_id);
CREATE INDEX idx_direct_messages_conversation_created_at ON public.direct_messages(conversation_id, created_at DESC);
CREATE INDEX idx_direct_conversations_updated_at ON public.direct_conversations(updated_at DESC);