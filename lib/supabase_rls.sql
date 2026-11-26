-- Run once in Supabase: SQL Editor. Makes sure every user can only see and change their own row of app_data.
alter table public.app_data enable row level security;

drop policy if exists "own row select" on public.app_data;
drop policy if exists "own row insert" on public.app_data;
drop policy if exists "own row update" on public.app_data;
drop policy if exists "own row delete" on public.app_data;

create policy "own row select" on public.app_data for select using (auth.uid() = user_id);
create policy "own row insert" on public.app_data for insert with check (auth.uid() = user_id);
create policy "own row update" on public.app_data for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own row delete" on public.app_data for delete using (auth.uid() = user_id);

-- To check afterwards: Authentication > Policies should list the four policies on app_data,
-- and the table should show "RLS enabled". (Realtime must stay enabled for app_data too.)
