alter table public.marawis_quiz_questions drop column if exists correct_index;
create or replace function public.submit_marawis_quiz(p_quiz_id bigint,p_answers jsonb) returns table(score int,total_questions int) language plpgsql security definer set search_path=public as $$
declare v_user uuid:=auth.uid(); v_total int; v_correct int:=0; v_i int:=0; v_q record; v_choice int;
begin
if v_user is null then raise exception 'Login diperlukan'; end if;
if not exists(select 1 from public.marawis_quizzes where id=p_quiz_id and published=true) then raise exception 'Quiz tidak tersedia'; end if;
if jsonb_typeof(p_answers)<>'array' then raise exception 'Format jawaban tidak valid'; end if;
select count(*) into v_total from public.marawis_quiz_questions where quiz_id=p_quiz_id;
if v_total=0 or jsonb_array_length(p_answers)<>v_total then raise exception 'Jumlah jawaban tidak sesuai'; end if;
for v_q in select q.id,a.correct_index from public.marawis_quiz_questions q join public.marawis_quiz_answers a on a.question_id=q.id where q.quiz_id=p_quiz_id order by q.sort_order,q.id loop
v_choice:=case when p_answers->>v_i ~ '^[0-3]$' then (p_answers->>v_i)::int else -1 end;
if v_choice=v_q.correct_index then v_correct:=v_correct+1; end if; v_i:=v_i+1; end loop;
insert into public.marawis_quiz_attempts(quiz_id,user_id,answers,score,total_questions,submitted_at) values(p_quiz_id,v_user,p_answers,round(v_correct*100.0/v_total)::int,v_total,now());
return query select round(v_correct*100.0/v_total)::int,v_total;
end; $$;
revoke all on function public.submit_marawis_quiz(bigint,jsonb) from public,anon; grant execute on function public.submit_marawis_quiz(bigint,jsonb) to authenticated;