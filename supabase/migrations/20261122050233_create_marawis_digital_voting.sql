create table public.marawis_votes (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 3 and 160),
  description text not null default '',
  status text not null default 'open' check (status in ('open','closed')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create table public.marawis_vote_options (
  id uuid primary key default gen_random_uuid(),
  vote_id uuid not null references public.marawis_votes(id) on delete cascade,
  label text not null check (char_length(trim(label)) between 1 and 180),
  position integer not null default 0,
  unique (vote_id, id),
  unique (vote_id, position)
);

create table public.marawis_vote_ballots (
  id uuid primary key default gen_random_uuid(),
  vote_id uuid not null,
  option_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint marawis_vote_ballots_one_per_user unique (vote_id, user_id),
  constraint marawis_vote_ballots_option_belongs_to_vote
    foreign key (vote_id, option_id)
    references public.marawis_vote_options(vote_id, id)
    on delete cascade
);

create index marawis_votes_status_created_idx on public.marawis_votes(status, created_at desc);
create index marawis_vote_options_vote_idx on public.marawis_vote_options(vote_id, position);
create index marawis_vote_ballots_vote_idx on public.marawis_vote_ballots(vote_id);

alter table public.marawis_votes enable row level security;
alter table public.marawis_vote_options enable row level security;
alter table public.marawis_vote_ballots enable row level security;

grant select on public.marawis_votes, public.marawis_vote_options to authenticated;
grant insert, update on public.marawis_votes to authenticated;
grant insert on public.marawis_vote_options to authenticated;
grant select, insert on public.marawis_vote_ballots to authenticated;

create policy "Authenticated users can read votes"
on public.marawis_votes for select to authenticated using (true);

create policy "Staff can create votes"
on public.marawis_votes for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('pengurus','pembina'))
);

create policy "Staff can update votes"
on public.marawis_votes for update to authenticated
using (exists (select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role in ('pengurus','pembina')))
with check (exists (select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role in ('pengurus','pembina')));

create policy "Authenticated users can read vote options"
on public.marawis_vote_options for select to authenticated using (true);

create policy "Staff can add vote options"
on public.marawis_vote_options for insert to authenticated
with check (
  exists (select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('pengurus','pembina'))
  and exists (select 1 from public.marawis_votes v
    where v.id = vote_id and v.created_by = (select auth.uid()))
);

create policy "Users can read only their own ballot"
on public.marawis_vote_ballots for select to authenticated
using (user_id = (select auth.uid()));

create policy "Users can cast one ballot in an open vote"
on public.marawis_vote_ballots for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (select 1 from public.marawis_votes v
    where v.id = vote_id and v.status = 'open'
      and v.starts_at <= now() and (v.ends_at is null or v.ends_at > now()))
);

create view public.marawis_vote_results as
select o.vote_id, o.id as option_id, o.label as option_label,
       count(b.id)::bigint as vote_count
from public.marawis_vote_options o
left join public.marawis_vote_ballots b
  on b.vote_id = o.vote_id and b.option_id = o.id
group by o.vote_id, o.id, o.label, o.position
order by o.position;

revoke all on public.marawis_vote_results from anon;
grant select on public.marawis_vote_results to authenticated;
