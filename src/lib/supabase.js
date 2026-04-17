import { createClient } from '@supabase/supabase-js';

const fallbackUrl = 'https://ktbpsliejglodmonmzhs.supabase.co';
const fallbackAnonKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt0YnBzbGllamdsb2Rtb25temhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0NDA2MTYsImV4cCI6MjA5MjAxNjYxNn0.WMwO-DFKZeMDb8MTy7qjBs6zdX_bP6vdC0ffF5V0KLg';

export const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || fallbackUrl;
export const supabaseAnonKey =
  import.meta.env.VITE_SUPABASE_ANON_KEY || fallbackAnonKey;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export async function runQuery(label, query) {
  const { data, error } = await query;

  if (error) {
    throw new Error(`${label}: ${error.message}`);
  }

  return data;
}
