create extension if not exists vector with schema extensions;

create table if not exists public.resume_embeddings (
    id bigint generated always as identity primary key,
    user_id text not null,
    resume_path text not null,
    chunk_index integer not null check (chunk_index >= 0),
    content text not null,
    embedding extensions.vector(768) not null,
    created_at timestamptz not null default now(),
    unique (user_id, resume_path, chunk_index)
);

create index if not exists resume_embeddings_embedding_hnsw_idx
    on public.resume_embeddings
    using hnsw (embedding extensions.vector_cosine_ops);

alter table public.resume_embeddings enable row level security;
revoke all on public.resume_embeddings from public, anon, authenticated;
grant all on public.resume_embeddings to service_role;

create or replace function public.replace_resume_embeddings(
    p_user_id text,
    p_resume_path text,
    p_chunks jsonb
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
    inserted_count integer;
begin
    if p_user_id is null or p_user_id = ''
        or p_resume_path is null
        or left(p_resume_path, length(p_user_id) + 1) <> (p_user_id || '/')
    then
        raise exception 'Invalid resume embedding payload.';
    end if;

    if p_chunks is null or jsonb_typeof(p_chunks) <> 'array' then
        raise exception 'Resume chunks must be a JSON array.';
    end if;

    if jsonb_array_length(p_chunks) = 0 then
        raise exception 'Resume chunks must not be empty.';
    end if;

    delete from public.resume_embeddings
    where user_id = p_user_id;

    insert into public.resume_embeddings (
        user_id,
        resume_path,
        chunk_index,
        content,
        embedding
    )
    select
        p_user_id,
        p_resume_path,
        (chunk->>'chunk_index')::integer,
        chunk->>'content',
        (chunk->>'embedding')::extensions.vector(768)
    from jsonb_array_elements(p_chunks) as chunks(chunk);

    get diagnostics inserted_count = row_count;
    return inserted_count;
end;
$$;

revoke all on function public.replace_resume_embeddings(text, text, jsonb)
    from public, anon, authenticated;
grant execute on function public.replace_resume_embeddings(text, text, jsonb)
    to service_role;
