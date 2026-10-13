-- ════════════════════════════════════════════════════════════════════════════
-- M1 — Esquema base de Imperium Iuris                    (SOLO DESARROLLO)
-- ════════════════════════════════════════════════════════════════════════════
-- Reproduce la ESTRUCTURA de producción según la auditoría de catálogos
-- del 2026-10-09: 7 tablas, 51 columnas, 15 restricciones, 2 índices
-- adicionales (los otros 8 los crean las restricciones), la función
-- set_updated_at() con su trigger y RLS activado en todas las tablas.
--
-- NO EJECUTAR EN PRODUCCIÓN: producción ya contiene estos objetos.
-- Aborta sin cambios si alguna de las 7 tablas ya existe en public.
--
-- Diferencias intencionales con producción (decisiones aprobadas):
--   · set_updated_at() fija search_path = '' (producción no lo fija).
--   · Permisos y políticas NO se crean aquí: van en M2.
--
-- Se conserva a propósito el estado actual de producción en
-- push_subscriptions (sin columna id y sin clave primaria). La corrección
-- del código que depende de ello va en un PR independiente.
--
-- Orden de aplicación: D1 (0 tablas) → M1 → M2 → M3 → seed.sql
--
-- CÓMO EJECUTARLO (Supabase → SQL Editor de imperium-iuris-dev):
--   1. Ejecuta el archivo COMPLETO, sin texto seleccionado. Con una
--      selección, el editor solo ejecuta esa parte y podría saltarse
--      el BEGIN o la comprobación previa.
--   2. Si ocurre un error y la sesión queda en una transacción abortada
--      ("current transaction is aborted"), ejecuta únicamente
--         ROLLBACK;
--      antes de cualquier otra instrucción.
-- ════════════════════════════════════════════════════════════════════════════

begin;

-- ─── Comprobación previa ────────────────────────────────────────────────────
do $$
declare
  existentes text;
begin
  select string_agg(c.relname::text, ', ' order by c.relname)
    into existentes
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in ('configuracion', 'articulos', 'citas', 'consultas',
                       'testimonios', 'mensajes', 'push_subscriptions');

  if existentes is not null then
    raise exception 'M1 ABORTADA: ya existen en public: %. ¿Estás en producción o M1 ya se aplicó?', existentes;
  end if;
end
$$;

-- ─── configuracion ──────────────────────────────────────────────────────────
create table public.configuracion (
  clave      text        not null,
  valor      jsonb       not null,
  updated_at timestamptz not null default now(),
  constraint configuracion_pkey primary key (clave)
);

-- ─── articulos ──────────────────────────────────────────────────────────────
-- updated_at no tiene trigger en producción: lo actualiza el código (PATCH).
create table public.articulos (
  id             uuid        not null default gen_random_uuid(),
  titulo         text        not null,
  slug           text        not null,
  categoria      text        not null,
  resumen        text,
  contenido      text        not null,
  tiempo_lectura text        not null default '5 min',
  publicado      boolean     not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint articulos_pkey     primary key (id),
  constraint articulos_slug_key unique (slug)
);

-- ─── citas ──────────────────────────────────────────────────────────────────
-- cliente_id va al final: en producción se añadió después (posición 11).
create table public.citas (
  id            uuid                   not null default gen_random_uuid(),
  nombre        text                   not null,
  correo        text                   not null,
  telefono      text                   not null,
  tipo_consulta text                   not null,
  fecha         date                   not null,
  hora          time without time zone not null,
  mensaje       text,
  estado        text                   not null default 'pendiente',
  created_at    timestamptz            not null default now(),
  cliente_id    uuid,
  constraint citas_pkey primary key (id),
  constraint citas_estado_check
    check (estado in ('pendiente', 'confirmada', 'cancelada')),
  constraint citas_cliente_id_fkey
    foreign key (cliente_id) references auth.users (id) on delete set null
);

create index citas_cliente_id_idx on public.citas using btree (cliente_id);

-- ─── consultas ──────────────────────────────────────────────────────────────
create table public.consultas (
  id            uuid        not null default gen_random_uuid(),
  nombre        text        not null,
  correo        text        not null,
  telefono      text        not null,
  tipo_consulta text        not null,
  mensaje       text        not null,
  confidencial  boolean     not null default false,
  estado        text        not null default 'nuevo',
  created_at    timestamptz not null default now(),
  constraint consultas_pkey primary key (id),
  constraint consultas_estado_check
    check (estado in ('nuevo', 'leido', 'respondido', 'archivado'))
);

-- ─── testimonios ────────────────────────────────────────────────────────────
create table public.testimonios (
  id           uuid        not null default gen_random_uuid(),
  nombre       text        not null,
  cargo        text,
  empresa      text,
  texto        text        not null,
  calificacion integer     not null default 5,
  estado       text        not null default 'pendiente',
  created_at   timestamptz not null default now(),
  constraint testimonios_pkey primary key (id),
  constraint testimonios_calificacion_check
    check (calificacion >= 1 and calificacion <= 5),
  constraint testimonios_estado_check
    check (estado in ('pendiente', 'aprobado', 'rechazado'))
);

-- ─── mensajes ───────────────────────────────────────────────────────────────
create table public.mensajes (
  id         uuid        not null default gen_random_uuid(),
  cliente_id uuid        not null,
  remitente  text        not null,
  texto      text        not null,
  created_at timestamptz not null default now(),
  leido      boolean     not null default false,
  constraint mensajes_pkey primary key (id),
  constraint mensajes_remitente_check
    check (remitente in ('cliente', 'abogado')),
  constraint mensajes_cliente_id_fkey
    foreign key (cliente_id) references auth.users (id) on delete cascade
);

create index mensajes_cliente_created_idx
  on public.mensajes using btree (cliente_id, created_at);

-- ─── push_subscriptions ─────────────────────────────────────────────────────
-- Igual que producción: sin id y sin clave primaria; endpoint es UNIQUE.
create table public.push_subscriptions (
  endpoint   text        not null,
  p256dh     text        not null,
  auth       text        not null,
  created_at timestamptz not null default now(),
  constraint push_subscriptions_endpoint_key unique (endpoint)
);

-- ─── Función y trigger de updated_at ────────────────────────────────────────
-- create (sin "or replace"): falla si la función ya existe.
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger configuracion_updated_at
  before update on public.configuracion
  for each row execute function public.set_updated_at();

-- ─── RLS explícito ──────────────────────────────────────────────────────────
-- En dev, el event trigger ensure_rls ya lo activa al crear cada tabla;
-- se declara igualmente para no depender de él (repetirlo no tiene efecto).
alter table public.configuracion      enable row level security;
alter table public.articulos          enable row level security;
alter table public.citas              enable row level security;
alter table public.consultas          enable row level security;
alter table public.testimonios        enable row level security;
alter table public.mensajes           enable row level security;
alter table public.push_subscriptions enable row level security;

commit;
