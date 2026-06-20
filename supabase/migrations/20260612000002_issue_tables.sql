-- Add new columns to reports table
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'issue';
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS ward text;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS video_urls text[] NOT NULL DEFAULT '{}';
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS like_count integer NOT NULL DEFAULT 0;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS comment_count integer NOT NULL DEFAULT 0;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS verification_count integer NOT NULL DEFAULT 0;

-- Comments
CREATE TABLE IF NOT EXISTS public.issue_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_id uuid NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL CHECK (char_length(content) BETWEEN 1 AND 1000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Votes (like / verify)
CREATE TABLE IF NOT EXISTS public.issue_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_id uuid NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vote_type text NOT NULL CHECK (vote_type IN ('like', 'verify')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (issue_id, user_id, vote_type)
);

-- Government authorities
CREATE TABLE IF NOT EXISTS public.authorities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  department text NOT NULL,
  city text NOT NULL,
  ward text,
  contact_email text,
  contact_phone text,
  website_url text,
  categories text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Elected representatives
CREATE TABLE IF NOT EXISTS public.representatives (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  party text,
  constituency text NOT NULL,
  city text NOT NULL,
  ward text,
  contact_email text,
  contact_phone text,
  photo_url text,
  role text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_issue_comments_issue_id ON public.issue_comments(issue_id);
CREATE INDEX IF NOT EXISTS idx_issue_votes_issue_id ON public.issue_votes(issue_id);
CREATE INDEX IF NOT EXISTS idx_issue_votes_user_id ON public.issue_votes(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_city ON public.reports(city);
CREATE INDEX IF NOT EXISTS idx_reports_type ON public.reports(type);
CREATE INDEX IF NOT EXISTS idx_authorities_city ON public.authorities(city);
CREATE INDEX IF NOT EXISTS idx_representatives_city ON public.representatives(city);

-- RLS
ALTER TABLE public.issue_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issue_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.authorities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.representatives ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN CREATE POLICY "view_comments" ON public.issue_comments FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "insert_comments" ON public.issue_comments FOR INSERT WITH CHECK (auth.uid() = user_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "delete_own_comments" ON public.issue_comments FOR DELETE USING (auth.uid() = user_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE POLICY "view_votes" ON public.issue_votes FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "insert_votes" ON public.issue_votes FOR INSERT WITH CHECK (auth.uid() = user_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "delete_own_votes" ON public.issue_votes FOR DELETE USING (auth.uid() = user_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE POLICY "view_authorities" ON public.authorities FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "view_representatives" ON public.representatives FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- sync comment_count on reports
CREATE OR REPLACE FUNCTION public.sync_comment_count() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.reports SET comment_count = comment_count + 1 WHERE id = NEW.issue_id;
    RETURN NEW;
  ELSE
    UPDATE public.reports SET comment_count = GREATEST(0, comment_count - 1) WHERE id = OLD.issue_id;
    RETURN OLD;
  END IF;
END;
$$;
DROP TRIGGER IF EXISTS trg_comment_count_ins ON public.issue_comments;
DROP TRIGGER IF EXISTS trg_comment_count_del ON public.issue_comments;
CREATE TRIGGER trg_comment_count_ins AFTER INSERT ON public.issue_comments FOR EACH ROW EXECUTE FUNCTION public.sync_comment_count();
CREATE TRIGGER trg_comment_count_del AFTER DELETE ON public.issue_comments FOR EACH ROW EXECUTE FUNCTION public.sync_comment_count();

-- sync like_count / verification_count on reports
CREATE OR REPLACE FUNCTION public.sync_vote_count() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.vote_type = 'like' THEN UPDATE public.reports SET like_count = like_count + 1 WHERE id = NEW.issue_id;
    ELSIF NEW.vote_type = 'verify' THEN UPDATE public.reports SET verification_count = verification_count + 1 WHERE id = NEW.issue_id;
    END IF;
    RETURN NEW;
  ELSE
    IF OLD.vote_type = 'like' THEN UPDATE public.reports SET like_count = GREATEST(0, like_count - 1) WHERE id = OLD.issue_id;
    ELSIF OLD.vote_type = 'verify' THEN UPDATE public.reports SET verification_count = GREATEST(0, verification_count - 1) WHERE id = OLD.issue_id;
    END IF;
    RETURN OLD;
  END IF;
END;
$$;
DROP TRIGGER IF EXISTS trg_vote_count_ins ON public.issue_votes;
DROP TRIGGER IF EXISTS trg_vote_count_del ON public.issue_votes;
CREATE TRIGGER trg_vote_count_ins AFTER INSERT ON public.issue_votes FOR EACH ROW EXECUTE FUNCTION public.sync_vote_count();
CREATE TRIGGER trg_vote_count_del AFTER DELETE ON public.issue_votes FOR EACH ROW EXECUTE FUNCTION public.sync_vote_count();

-- Seed authorities
INSERT INTO public.authorities (name, department, city, categories) VALUES
  ('BMC - Roads Department', 'Roads & Infrastructure', 'Mumbai', ARRAY['infrastructure','roads']),
  ('BMC - Water Supply', 'Water Supply', 'Mumbai', ARRAY['water']),
  ('BEST - Bus Services', 'Transport', 'Mumbai', ARRAY['transport']),
  ('Mumbai Traffic Police', 'Traffic & Safety', 'Mumbai', ARRAY['safety','roads']),
  ('MPCB - Pollution Control', 'Environment', 'Mumbai', ARRAY['environment']),
  ('Pune Municipal Corporation', 'Municipal', 'Pune', ARRAY['infrastructure','water','roads']),
  ('PCMC', 'Municipal', 'Pune', ARRAY['infrastructure','environment']),
  ('Delhi MCD - North', 'Municipal', 'Delhi', ARRAY['infrastructure','water','environment']),
  ('Delhi Traffic Police', 'Traffic & Safety', 'Delhi', ARRAY['safety','roads']),
  ('BBMP', 'Municipal', 'Bengaluru', ARRAY['infrastructure','water','environment','roads']),
  ('Chennai Corporation', 'Municipal', 'Chennai', ARRAY['infrastructure','water','environment'])
ON CONFLICT DO NOTHING;
