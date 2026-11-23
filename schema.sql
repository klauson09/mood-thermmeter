-- 情緒溫度計：Supabase schema
-- 在 Supabase Dashboard > SQL Editor 貼上並執行整份 SQL。
create extension if not exists pgcrypto;

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  invite_code text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '星星旅人' check (char_length(display_name) between 1 and 24),
  room_id uuid references public.rooms(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.mood_entries (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  entry_date date not null default current_date,
  joy int not null default 0 check (joy between 0 and 100),
  anger int not null default 0 check (anger between 0 and 100),
  sadness int not null default 0 check (sadness between 0 and 100),
  delight int not null default 0 check (delight between 0 and 100),
  note text not null default '' check (char_length(note) <= 2000),
  is_shared boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, entry_date)
);

create index if not exists mood_entries_room_date_idx on public.mood_entries(room_id, entry_date desc);
create index if not exists profiles_room_idx on public.profiles(room_id);

alter table public.rooms enable row level security;
alter table public.profiles enable row level security;
alter table public.mood_entries enable row level security;

-- 以 SECURITY DEFINER 取得目前使用者的小屋，避免 RLS policy 互相遞迴。
create or replace function public.current_mood_room_id()
returns uuid language sql stable security definer set search_path=public
as $$
  select room_id from public.profiles where id=auth.uid()
$$;
revoke all on function public.current_mood_room_id() from public;
grant execute on function public.current_mood_room_id() to authenticated;

-- 只允許已登入成員讀取同一個小屋；個人 profile 只顯示暱稱。
create policy "room members can read room" on public.rooms for select to authenticated
using (exists(select 1 from public.profiles p where p.id=auth.uid() and p.room_id=rooms.id));
create policy "members can read profiles in same room" on public.profiles for select to authenticated
using (id=auth.uid() or (room_id is not null and room_id=public.current_mood_room_id()));
create policy "users can insert own profile" on public.profiles for insert to authenticated
with check (id=auth.uid());
create policy "users can update own profile" on public.profiles for update to authenticated
using (id=auth.uid()) with check (id=auth.uid());
create policy "members can read shared entries and own private entries" on public.mood_entries for select to authenticated
using (user_id=auth.uid() or (is_shared=true and room_id=public.current_mood_room_id()));
create policy "users can insert own entries in own room" on public.mood_entries for insert to authenticated
with check (user_id=auth.uid() and room_id=public.current_mood_room_id());
create policy "users can update own entries" on public.mood_entries for update to authenticated
using (user_id=auth.uid() and room_id=public.current_mood_room_id())
with check (user_id=auth.uid() and room_id=public.current_mood_room_id());
create policy "users can delete own entries" on public.mood_entries for delete to authenticated
using (user_id=auth.uid());

-- 產生個人小屋。回傳房間資料；呼叫者成為第一位成員。
create or replace function public.create_mood_room(p_room_name text, p_display_name text)
returns public.rooms language plpgsql security definer set search_path=public
as $$
declare v_room public.rooms; v_code text;
begin
 if auth.uid() is null then raise exception '請先登入'; end if;
 if length(trim(p_room_name)) not between 1 and 40 then raise exception '小屋名稱請輸入 1～40 個字'; end if;
 if length(trim(p_display_name)) not between 1 and 24 then raise exception '暱稱請輸入 1～24 個字'; end if;
 insert into public.profiles(id,display_name,room_id) values(auth.uid(),trim(p_display_name),null)
 on conflict(id) do update set display_name=excluded.display_name,room_id=null;
 loop
   v_code := upper(substr(encode(gen_random_bytes(6),'hex'),1,8));
   exit when not exists(select 1 from public.rooms where invite_code=v_code);
 end loop;
 insert into public.rooms(name,invite_code,created_by) values(trim(p_room_name),v_code,auth.uid()) returning * into v_room;
 update public.profiles set room_id=v_room.id where id=auth.uid();
 return v_room;
end; $$;

-- 使用邀請碼加入小屋；不需要知道房間 UUID。
create or replace function public.join_mood_room(p_invite_code text, p_display_name text)
returns public.rooms language plpgsql security definer set search_path=public
as $$
declare v_room public.rooms;
begin
 if auth.uid() is null then raise exception '請先登入'; end if;
 if length(trim(p_display_name)) not between 1 and 24 then raise exception '暱稱請輸入 1～24 個字'; end if;
 select * into v_room from public.rooms where invite_code=upper(trim(p_invite_code));
 if not found then raise exception '邀請碼不存在，請確認後再試一次'; end if;
 insert into public.profiles(id,display_name,room_id) values(auth.uid(),trim(p_display_name),v_room.id)
 on conflict(id) do update set display_name=excluded.display_name,room_id=excluded.room_id;
 return v_room;
end; $$;

revoke all on function public.create_mood_room(text,text) from public;
revoke all on function public.join_mood_room(text,text) from public;
grant execute on function public.create_mood_room(text,text) to authenticated;
grant execute on function public.join_mood_room(text,text) to authenticated;
grant select on public.rooms, public.profiles, public.mood_entries to authenticated;
grant insert,update,delete on public.mood_entries to authenticated;
grant insert,update on public.profiles to authenticated;
