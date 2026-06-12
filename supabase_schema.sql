-- ═══════════════════════════════════════
-- TURF - Supabase Database Schema
-- Run this in Supabase SQL Editor
-- ═══════════════════════════════════════

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── USERS ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  username TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  cover_url TEXT,
  bio TEXT,
  city TEXT,
  level INTEGER DEFAULT 1,
  km_ran DECIMAL DEFAULT 0,
  territories_captured INTEGER DEFAULT 0,
  territories_defended INTEGER DEFAULT 0,
  current_streak INTEGER DEFAULT 0,
  max_streak INTEGER DEFAULT 0,
  clan_id UUID,
  skin_id TEXT DEFAULT 'default',
  trail_id TEXT DEFAULT 'default',
  coins INTEGER DEFAULT 100,
  is_online BOOLEAN DEFAULT false,
  share_location BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── CLANS ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.clans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  slogan TEXT,
  flag_url TEXT,
  color TEXT DEFAULT '#5B5BD6',
  boss_id UUID REFERENCES public.users(id),
  member_count INTEGER DEFAULT 1,
  territory_count INTEGER DEFAULT 0,
  rank TEXT DEFAULT 'Street Crew',
  is_open BOOLEAN DEFAULT false,
  max_members INTEGER DEFAULT 30,
  city TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── CLAN MEMBERS ───────────────────────
CREATE TABLE IF NOT EXISTS public.clan_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  clan_id UUID REFERENCES public.clans(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'prospect',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, clan_id)
);

-- ── CLAN MESSAGES ──────────────────────
CREATE TABLE IF NOT EXISTS public.clan_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  clan_id UUID REFERENCES public.clans(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  avatar_url TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── JOIN REQUESTS ──────────────────────
CREATE TABLE IF NOT EXISTS public.join_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  clan_id UUID REFERENCES public.clans(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, clan_id)
);

-- ── TERRITORIES ────────────────────────
CREATE TABLE IF NOT EXISTS public.territories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  clan_id UUID REFERENCES public.clans(id) ON DELETE CASCADE,
  clan_name TEXT,
  clan_flag_url TEXT,
  clan_color TEXT DEFAULT '#5B5BD6',
  points JSONB NOT NULL,
  area_sq_meters DECIMAL DEFAULT 0,
  captured_at TIMESTAMPTZ DEFAULT NOW(),
  captured_by UUID REFERENCES public.users(id)
);

-- ── LIVE PLAYERS ───────────────────────
CREATE TABLE IF NOT EXISTS public.live_players (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  username TEXT,
  latitude DECIMAL NOT NULL,
  longitude DECIMAL NOT NULL,
  speed_kmh DECIMAL DEFAULT 0,
  clan_id UUID,
  clan_color TEXT,
  skin_id TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── POSTS ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  clan_id UUID REFERENCES public.clans(id) ON DELETE CASCADE,
  clan_name TEXT,
  clan_flag_url TEXT,
  author_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  author_name TEXT,
  type TEXT DEFAULT 'regular',
  content TEXT,
  image_url TEXT,
  metadata JSONB,
  like_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  city TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── POST LIKES ─────────────────────────
CREATE TABLE IF NOT EXISTS public.post_likes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- ── COMMENTS ───────────────────────────
CREATE TABLE IF NOT EXISTS public.comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  username TEXT,
  avatar_url TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── SHOP ITEMS ─────────────────────────
CREATE TABLE IF NOT EXISTS public.shop_items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  preview_url TEXT,
  price INTEGER DEFAULT 0,
  is_free BOOLEAN DEFAULT false,
  is_limited BOOLEAN DEFAULT false,
  badge TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── USER ITEMS (owned) ─────────────────
CREATE TABLE IF NOT EXISTS public.user_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  item_id TEXT REFERENCES public.shop_items(id),
  purchased_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, item_id)
);

-- ── BUNDLES ────────────────────────────
CREATE TABLE IF NOT EXISTS public.bundles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  item_ids TEXT[] DEFAULT '{}',
  original_price INTEGER DEFAULT 0,
  discounted_price INTEGER DEFAULT 0,
  discount_percent DECIMAL DEFAULT 0,
  icon_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════
-- RLS POLICIES
-- ═══════════════════════════════════════

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clan_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clan_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bundles ENABLE ROW LEVEL SECURITY;

-- Users: anyone can read, only self can update
CREATE POLICY "users_select" ON public.users FOR SELECT USING (true);
CREATE POLICY "users_insert" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "users_update" ON public.users FOR UPDATE USING (auth.uid() = id);

-- Clans: anyone can read
CREATE POLICY "clans_select" ON public.clans FOR SELECT USING (true);
CREATE POLICY "clans_insert" ON public.clans FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "clans_update" ON public.clans FOR UPDATE USING (auth.uid() = boss_id);
CREATE POLICY "clans_delete" ON public.clans FOR DELETE USING (auth.uid() = boss_id);

-- Clan members: anyone can read
CREATE POLICY "members_select" ON public.clan_members FOR SELECT USING (true);
CREATE POLICY "members_insert" ON public.clan_members FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "members_delete" ON public.clan_members FOR DELETE USING (auth.uid() = user_id);

-- Clan messages: clan members only
CREATE POLICY "messages_select" ON public.clan_messages FOR SELECT USING (true);
CREATE POLICY "messages_insert" ON public.clan_messages FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Join requests
CREATE POLICY "requests_select" ON public.join_requests FOR SELECT USING (true);
CREATE POLICY "requests_insert" ON public.join_requests FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "requests_update" ON public.join_requests FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Territories: public read
CREATE POLICY "territories_select" ON public.territories FOR SELECT USING (true);
CREATE POLICY "territories_insert" ON public.territories FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "territories_delete" ON public.territories FOR DELETE USING (auth.uid() IS NOT NULL);

-- Live players
CREATE POLICY "live_select" ON public.live_players FOR SELECT USING (true);
CREATE POLICY "live_upsert" ON public.live_players FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "live_update" ON public.live_players FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "live_delete" ON public.live_players FOR DELETE USING (auth.uid() = user_id);

-- Posts
CREATE POLICY "posts_select" ON public.posts FOR SELECT USING (true);
CREATE POLICY "posts_insert" ON public.posts FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "posts_delete" ON public.posts FOR DELETE USING (auth.uid() = author_id);

-- Post likes
CREATE POLICY "likes_select" ON public.post_likes FOR SELECT USING (true);
CREATE POLICY "likes_insert" ON public.post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "likes_delete" ON public.post_likes FOR DELETE USING (auth.uid() = user_id);

-- Comments
CREATE POLICY "comments_select" ON public.comments FOR SELECT USING (true);
CREATE POLICY "comments_insert" ON public.comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "comments_delete" ON public.comments FOR DELETE USING (auth.uid() = user_id);

-- Shop items: public read
CREATE POLICY "shop_select" ON public.shop_items FOR SELECT USING (true);

-- User items
CREATE POLICY "user_items_select" ON public.user_items FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "user_items_insert" ON public.user_items FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Bundles: public read
CREATE POLICY "bundles_select" ON public.bundles FOR SELECT USING (true);

-- ═══════════════════════════════════════
-- REALTIME
-- ═══════════════════════════════════════

ALTER PUBLICATION supabase_realtime ADD TABLE public.territories;
ALTER PUBLICATION supabase_realtime ADD TABLE public.live_players;
ALTER PUBLICATION supabase_realtime ADD TABLE public.clan_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;

-- ═══════════════════════════════════════
-- FUNCTIONS
-- ═══════════════════════════════════════

CREATE OR REPLACE FUNCTION increment_member_count(clan_id UUID)
RETURNS void AS $$
  UPDATE public.clans SET member_count = member_count + 1 WHERE id = clan_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION decrement_member_count(clan_id UUID)
RETURNS void AS $$
  UPDATE public.clans SET member_count = GREATEST(0, member_count - 1) WHERE id = clan_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION increment_territory_count(clan_id UUID)
RETURNS void AS $$
  UPDATE public.clans SET territory_count = territory_count + 1 WHERE id = clan_id;
$$ LANGUAGE sql;

-- ═══════════════════════════════════════
-- STORAGE BUCKETS
-- (Run in Supabase Dashboard → Storage)
-- ═══════════════════════════════════════
-- Create bucket: media (public)
-- Allowed mime types: image/jpeg, image/png, image/webp
-- Max file size: 5MB
-- Folders: avatars/, covers/, clan_flags/, posts/

-- ═══════════════════════════════════════
-- DEFAULT SHOP ITEMS
-- ═══════════════════════════════════════
INSERT INTO public.shop_items (id, name, type, price, is_free, badge) VALUES
  ('default', 'Default', 'character', 0, true, null),
  ('wolf_starter', 'Wolf Starter', 'character', 0, true, 'free'),
  ('shadow_runner', 'Shadow Runner', 'character', 499, false, 'hot'),
  ('fire_runner', 'Fire Runner', 'character', 650, false, 'new'),
  ('ghost', 'Ghost', 'character', 400, false, null),
  ('neon_strike', 'Neon Strike', 'character', 550, false, null),
  ('trail_default', 'Default Trail', 'trail', 0, true, null),
  ('shadow_trail', 'Shadow Trail', 'trail', 200, false, null),
  ('fire_trail', 'Fire Trail', 'trail', 300, false, null),
  ('neon_trail', 'Neon Trail', 'trail', 350, false, null),
  ('ghost_trail', 'Ghost Trail', 'trail', 250, false, null)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.bundles (name, description, item_ids, original_price, discounted_price, discount_percent) VALUES
  ('Starter Pack', 'Everything to dominate from day 1', ARRAY['shadow_runner', 'shadow_trail'], 699, 499, 40),
  ('War Pack', 'For serious territory fighters', ARRAY['fire_runner', 'fire_trail'], 950, 799, 50)
ON CONFLICT DO NOTHING;
