create table notes (
  id bigserial primary key,
  title text not null,
  body text not null,
  tag text not null,
  created_at timestamptz not null
);
create index notes_tag_id on notes (tag, id desc);
