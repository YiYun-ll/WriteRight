-- T is an independent English-to-Chinese practice rubric; A/B and old reports are unchanged.
alter table public.essay_tasks drop constraint essay_tasks_part_check;
alter table public.essay_tasks add constraint essay_tasks_part_check check (part in ('A', 'B', 'T'));
alter table public.grading_reports drop constraint grading_reports_part_check;
alter table public.grading_reports add constraint grading_reports_part_check check (part in ('A', 'B', 'T'));
-- Quarter-point typo deductions must survive storage without rounding to tenths.
alter table public.grading_reports alter column score type numeric(5,2);
alter table public.grading_reports drop constraint grading_reports_check;
alter table public.grading_reports add constraint grading_reports_check check (
    (score is null and max_score is null and band is null)
    or (score is not null and max_score is not null and band is not null and
        ((part = 'A' and max_score = 10 and score between 0 and 10)
         or (part in ('B', 'T') and max_score = 15 and score between 0 and 15)))
);
