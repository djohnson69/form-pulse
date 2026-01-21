-- AI Chat Tables for conversation persistence
-- Migration: 20260119200000_add_ai_chat_tables.sql

-- AI Conversations table
CREATE TABLE IF NOT EXISTS ai_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  org_id UUID REFERENCES orgs(id) ON DELETE SET NULL,
  title TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  archived_at TIMESTAMPTZ
);

-- AI Chat Messages table
CREATE TABLE IF NOT EXISTS ai_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user ON ai_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_updated ON ai_conversations(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_chat_messages_conversation ON ai_chat_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_ai_chat_messages_created ON ai_chat_messages(created_at);

-- Enable RLS
ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_chat_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for ai_conversations
CREATE POLICY "Users can view own conversations"
  ON ai_conversations FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can create own conversations"
  ON ai_conversations FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own conversations"
  ON ai_conversations FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own conversations"
  ON ai_conversations FOR DELETE
  USING (user_id = auth.uid());

-- RLS Policies for ai_chat_messages
CREATE POLICY "Users can view messages in own conversations"
  ON ai_chat_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM ai_conversations c
      WHERE c.id = ai_chat_messages.conversation_id
        AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create messages in own conversations"
  ON ai_chat_messages FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM ai_conversations c
      WHERE c.id = ai_chat_messages.conversation_id
        AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete messages in own conversations"
  ON ai_chat_messages FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM ai_conversations c
      WHERE c.id = ai_chat_messages.conversation_id
        AND c.user_id = auth.uid()
    )
  );

-- Trigger to update updated_at on conversation when messages are added
CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE ai_conversations
  SET updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ai_chat_messages_update_conversation
  AFTER INSERT ON ai_chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_timestamp();
