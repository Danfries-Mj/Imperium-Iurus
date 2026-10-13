-- ════════════════════════════════════════════════════════════════════════════
-- M3 — Realtime de mensajes y bucket site-images         (SOLO DESARROLLO)
-- ════════════════════════════════════════════════════════════════════════════
-- Afecta a dos objetos COMPARTIDOS fuera de las 7 tablas:
--   · la publicación supabase_realtime (se le añade public.mensajes);
--   · storage.buckets (se inserta una fila: el bucket site-images).
--
-- Realtime: igual que producción (insert/update/delete/truncate publicados,
-- sin FOR ALL TABLES; replica identity por defecto). La app solo escucha
-- INSERT en mensajes, filtrados por cliente_id.
--
-- Bucket: público como en producción, pero con los mismos límites que ya
-- aplica el código en /api/admin/configuracion/upload (5 MB y JPEG, PNG,
-- WebP o AVIF). Producción no tiene límites: diferencia intencional.
-- Las subidas usan service_role, así que no se crean políticas en
-- storage.objects; la lectura pública funciona por ser un bucket público.
--
-- Si el INSERT en storage.buckets falla por permisos, toda M3 se revierte.
-- Alternativa: crear el bucket desde el panel (Storage → New bucket) con
-- los mismos valores (público, 5 MB, image/jpeg, image/png, image/webp,
-- image/avif) y aplicar M3 omitiendo DOS partes:
--   · la sección "2. Storage" (el INSERT en storage.buckets), y
--   · la comprobación previa que aborta si el bucket site-images ya existe
--     ("M3 ABORTADA: el bucket site-images ya existe"), que de lo contrario
--     detendría M3 porque el bucket ya se habría creado a mano.
--
-- NO EJECUTAR EN PRODUCCIÓN. Mismas comprobaciones previas que M2.
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
  faltan text;
begin
  select string_agg(t, ', ' order by t)
    into faltan
    from unnest(array['configuracion', 'articulos', 'citas', 'consultas',
                      'testimonios', 'mensajes', 'push_subscriptions']) as t
   where pg_catalog.to_regclass('public.' || t) is null;

  if faltan is not null then
    raise exception 'M3 ABORTADA: faltan tablas en public: %. Aplica M1 y M2 primero.', faltan;
  end if;

  if exists (select 1 from public.citas) or exists (select 1 from public.consultas) then
    raise exception 'M3 ABORTADA: citas o consultas contienen filas. M3 solo se aplica en un dev recién creado, antes de seed.sql. ¿Estás en producción?';
  end if;

  if not exists (select 1 from pg_catalog.pg_publication p
                  where p.pubname = 'supabase_realtime') then
    raise exception 'M3 ABORTADA: no existe la publicación supabase_realtime.';
  end if;

  if exists (select 1 from pg_catalog.pg_publication p
              where p.pubname = 'supabase_realtime' and p.puballtables) then
    raise exception 'M3 ABORTADA: supabase_realtime es FOR ALL TABLES; no se esperaba esa configuración.';
  end if;

  if exists (select 1 from pg_catalog.pg_publication_tables pt
              where pt.pubname = 'supabase_realtime'
                and pt.schemaname = 'public' and pt.tablename = 'mensajes') then
    raise exception 'M3 ABORTADA: public.mensajes ya está en supabase_realtime.';
  end if;

  if exists (select 1 from storage.buckets b where b.id = 'site-images') then
    raise exception 'M3 ABORTADA: el bucket site-images ya existe.';
  end if;
end
$$;

-- ─── 1. Realtime ────────────────────────────────────────────────────────────
alter publication supabase_realtime add table public.mensajes;

-- ─── 2. Storage ─────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'site-images',
  'site-images',
  true,
  5242880,  -- 5 MB = 5 * 1024 * 1024, igual que MAX_BYTES en upload/route.ts
  array['image/jpeg', 'image/png', 'image/webp', 'image/avif']
);

commit;
