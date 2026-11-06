create extension if not exists vector with schema extensions;

create table if not exists public.job_embeddings (
    id bigint generated always as identity primary key,
    job_id text not null,
    chunk_index integer not null check (chunk_index >= 0),
    content text not null,
    embedding extensions.vector(768) not null,
    created_at timestamptz not null default now(),
    unique (job_id, chunk_index)
);

create index if not exists job_embeddings_embedding_hnsw_idx
    on public.job_embeddings
    using hnsw (embedding extensions.vector_cosine_ops);

alter table public.job_embeddings enable row level security;
revoke all on public.job_embeddings from public, anon, authenticated;
grant all on public.job_embeddings to service_role;

create or replace function public.replace_job_embeddings(
    p_job_id text,
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
    if p_job_id is null or p_job_id = '' then
        raise exception 'Invalid job embedding payload.';
    end if;

    if p_chunks is null or jsonb_typeof(p_chunks) <> 'array' then
        raise exception 'Job chunks must be a JSON array.';
    end if;

    if jsonb_array_length(p_chunks) = 0 then
        raise exception 'Job chunks must not be empty.';
    end if;

    delete from public.job_embeddings
    where job_id = p_job_id;

    insert into public.job_embeddings (
        job_id,
        chunk_index,
        content,
        embedding
    )
    select
        p_job_id,
        (chunk->>'chunk_index')::integer,
        chunk->>'content',
        (chunk->>'embedding')::extensions.vector(768)
    from jsonb_array_elements(p_chunks) as chunks(chunk);

    get diagnostics inserted_count = row_count;
    return inserted_count;
end;
$$;

revoke all on function public.replace_job_embeddings(text, jsonb)
    from public, anon, authenticated;
grant execute on function public.replace_job_embeddings(text, jsonb)
    to service_role;
