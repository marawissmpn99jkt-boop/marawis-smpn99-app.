create or replace view public.marawis_vote_results as
select
  o.vote_id,
  o.id as option_id,
  o.label as option_label,
  count(b.id)::bigint as vote_count
from public.marawis_vote_options o
join public.marawis_votes v on v.id = o.vote_id
left join public.marawis_vote_ballots b
  on b.vote_id = o.vote_id and b.option_id = o.id
where v.status = 'closed'
   or (v.ends_at is not null and v.ends_at <= now())
group by o.vote_id, o.id, o.label, o.position
order by o.position;

revoke all on public.marawis_vote_results from anon;
grant select on public.marawis_vote_results to authenticated;

comment on view public.marawis_vote_results is
  'Aggregate voting results are visible only after a vote is closed or its deadline has passed.';
