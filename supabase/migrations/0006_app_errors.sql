CREATE TABLE app_errors (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz DEFAULT now(),
  timestamp text,
  module text,
  event text,
  error text,
  stack text,
  trailing_logs jsonb
);

-- Enable RLS
ALTER TABLE app_errors ENABLE ROW LEVEL SECURITY;

-- Allow anonymous and authenticated inserts (since crashes can happen pre-login)
CREATE POLICY "Allow inserts from anyone" ON app_errors
  FOR INSERT TO public
  WITH CHECK (true);

-- Only allow service role (Supabase Dashboard) to read the errors
CREATE POLICY "Allow service role read" ON app_errors
  FOR SELECT TO service_role
  USING (true);
