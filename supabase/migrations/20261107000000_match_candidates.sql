-- Semantic similarity between a job's stored vectors and every resume's vectors.
-- Reads public.candidate_resume_embeddings (the resume table in the live database)
-- and public.job_embeddings. Safe to run more than once.

create or replace function public.match_candidates_for_job(
    p_job_id text,
    p_limit integer default 20
)
returns table (
    user_id text,
    resume_path text,
    score double precision,
    profile_score double precision,
    skills_score double precision,
    work_score double precision,
    education_score double precision,
    experience_score double precision
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
    with job_sections as (
        select split_part(j.content, ':', 1) as section, j.embedding
        from public.job_embeddings j
        where j.job_id = p_job_id
    ),
    candidate_sections as (
        select c.user_id, c.resume_path,
               split_part(c.content, ':', 1) as section, c.embedding
        from public.candidate_resume_embeddings c
    ),
    weights(section, weight) as (
        values
            ('Technical Skills', 0.40::double precision),
            ('Professional Profile', 0.25),
            ('Work Experience', 0.20),
            ('Education Qualification', 0.10),
            ('Total Professional Experience', 0.05)
    ),
    job_weights as (
        select w.section, w.weight
        from weights w
        where exists (select 1 from job_sections js where js.section = w.section)
    ),
    candidates as (
        select distinct cs.user_id, cs.resume_path from candidate_sections cs
    ),
    pairs as (
        select cs.user_id, cs.resume_path, js.section as job_section,
               max(1 - (js.embedding <=> cs.embedding)) as similarity
        from job_sections js
        join candidate_sections cs
          on cs.section = any (
              case js.section
                  when 'Work Experience' then array['Work Experience', 'Projects']
                  else array[js.section]
              end
          )
        group by cs.user_id, cs.resume_path, js.section
    ),
    scored as (
        select c.user_id, c.resume_path, jw.section, jw.weight,
               coalesce(p.similarity, 0) as similarity
        from candidates c
        cross join job_weights jw
        left join pairs p
          on p.user_id = c.user_id
         and p.resume_path = c.resume_path
         and p.job_section = jw.section
    )
    select s.user_id,
           s.resume_path,
           sum(s.similarity * s.weight) / sum(s.weight) as score,
           max(s.similarity) filter (where s.section = 'Professional Profile'),
           max(s.similarity) filter (where s.section = 'Technical Skills'),
           max(s.similarity) filter (where s.section = 'Work Experience'),
           max(s.similarity) filter (where s.section = 'Education Qualification'),
           max(s.similarity) filter (where s.section = 'Total Professional Experience')
    from scored s
    group by s.user_id, s.resume_path
    order by score desc
    limit greatest(p_limit, 1);
$$;

revoke all on function public.match_candidates_for_job(text, integer)
    from public, anon, authenticated;
grant execute on function public.match_candidates_for_job(text, integer)
    to service_role;
