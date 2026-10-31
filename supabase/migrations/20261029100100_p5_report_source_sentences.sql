alter table public.grading_reports
    add column source_sentences_json jsonb not null default '[]'::jsonb
    check (jsonb_typeof(source_sentences_json) = 'array');
