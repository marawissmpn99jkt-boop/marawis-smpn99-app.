alter table public.marawis_quiz_questions
  add column if not exists question_type text not null default 'mcq' check (question_type in ('mcq','essay')),
  add column if not exists points integer not null default 1 check (points between 1 and 100),
  add column if not exists sample_answer text,
  add column if not exists rubric text;

alter table public.marawis_quiz_questions drop constraint if exists marawis_quiz_questions_options_check;
alter table public.marawis_quiz_questions add constraint marawis_quiz_questions_options_check
  check ((question_type='mcq' and jsonb_typeof(options)='array' and jsonb_array_length(options)=4)
      or (question_type='essay' and jsonb_typeof(options)='array' and jsonb_array_length(options)=0));

alter table public.marawis_quiz_answers alter column correct_index drop not null;
alter table public.marawis_quiz_attempts
  add column if not exists manual_score integer,
  add column if not exists final_score integer,
  add column if not exists review_status text not null default 'not_required' check (review_status in ('not_required','pending','reviewed')),
  add column if not exists reviewed_by uuid references auth.users(id),
  add column if not exists reviewed_at timestamptz;

drop policy if exists attempts_admin_update on public.marawis_quiz_attempts;
create policy attempts_admin_update on public.marawis_quiz_attempts for update to authenticated
using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('pengurus','pembina')))
with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('pengurus','pembina')));
grant update on public.marawis_quiz_attempts to authenticated;

drop function if exists public.submit_marawis_quiz(bigint,jsonb);
create function public.submit_marawis_quiz(p_quiz_id bigint,p_answers jsonb)
returns table(score int,total_questions int,review_pending boolean)
language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid(); v_total int; v_auto_count int:=0; v_correct int:=0;
  v_i int:=0; v_q record; v_choice int; v_answer jsonb; v_has_essay boolean:=false; v_score int:=0;
begin
  if v_user is null then raise exception 'Login diperlukan'; end if;
  if not exists(select 1 from public.marawis_quizzes where id=p_quiz_id and published=true) then raise exception 'Quiz tidak tersedia'; end if;
  if jsonb_typeof(p_answers)<>'array' then raise exception 'Format jawaban tidak valid'; end if;
  select count(*) into v_total from public.marawis_quiz_questions where quiz_id=p_quiz_id;
  if v_total=0 or jsonb_array_length(p_answers)<>v_total then raise exception 'Jumlah jawaban tidak sesuai'; end if;
  for v_q in
    select q.id,q.question_type,a.correct_index from public.marawis_quiz_questions q
    left join public.marawis_quiz_answers a on a.question_id=q.id
    where q.quiz_id=p_quiz_id order by q.sort_order,q.id
  loop
    v_answer:=p_answers->v_i;
    if v_q.question_type='essay' then v_has_essay:=true;
    else
      v_auto_count:=v_auto_count+1;
      v_choice:=case
        when jsonb_typeof(v_answer)='object' and coalesce(v_answer->>'choice','') ~ '^[0-3]$' then (v_answer->>'choice')::int
        when jsonb_typeof(v_answer)='number' and (v_answer#>>'{}') ~ '^[0-3]$' then (v_answer#>>'{}')::int
        else -1 end;
      if v_choice=v_q.correct_index then v_correct:=v_correct+1; end if;
    end if;
    v_i:=v_i+1;
  end loop;
  if v_auto_count>0 then v_score:=round(v_correct*100.0/v_auto_count)::int; end if;
  insert into public.marawis_quiz_attempts(quiz_id,user_id,answers,score,total_questions,submitted_at,review_status,final_score)
  values(p_quiz_id,v_user,p_answers,v_score,v_total,now(),case when v_has_essay then 'pending' else 'not_required' end,case when v_has_essay then null else v_score end);
  return query select v_score,v_total,v_has_essay;
end;
$$;
revoke all on function public.submit_marawis_quiz(bigint,jsonb) from public,anon;
grant execute on function public.submit_marawis_quiz(bigint,jsonb) to authenticated;
