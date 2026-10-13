-- ════════════════════════════════════════════════════════════════════════════
-- M2 — Permisos mínimos y políticas RLS                  (SOLO DESARROLLO)
-- ════════════════════════════════════════════════════════════════════════════
-- Sustituye los permisos predeterminados por la matriz mínima aprobada.
-- En dev, las tablas creadas por postgres reciben por defecto MAINTAIN,
-- REFERENCES, TRIGGER y TRUNCATE para anon, authenticated y service_role,
-- pero ningún CRUD: aquí se revoca todo y se concede solo lo necesario.
--
-- Matriz (derivada del uso real en el código):
--   anon          → nada (la clave anon solo se usa para Auth).
--   authenticated → mensajes: SELECT y UPDATE solo de la columna leido.
--   service_role  → CRUD por tabla según las rutas del servidor.
--                   BYPASSRLS = true (confirmado en D2), pero eso NO
--                   sustituye a los GRANT de tabla.
--
-- Diferencias intencionales con producción (decisiones aprobadas):
--   · Sin políticas public_read_*, config_*, insert_mensajes ni
--     service_role_all: el código no las usa.
--   · Políticas de mensajes rehechas, con WITH CHECK y solo para authenticated.
--
-- NO EJECUTAR EN PRODUCCIÓN. Aborta sin cambios si faltan las tablas de M1
-- o si citas o consultas contienen filas (producción tiene datos; dev
-- todavía no tiene la semilla en este punto).
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
    raise exception 'M2 ABORTADA: faltan tablas en public: %. Aplica M1 primero.', faltan;
  end if;

  if exists (select 1 from public.citas) or exists (select 1 from public.consultas) then
    raise exception 'M2 ABORTADA: citas o consultas contienen filas. M2 solo se aplica en un dev recién creado, antes de seed.sql. ¿Estás en producción?';
  end if;
end
$$;

-- ─── 1. Revocar todo en las 7 tablas ────────────────────────────────────────
-- Incluye MAINTAIN, REFERENCES, TRIGGER y TRUNCATE de los privilegios
-- predeterminados. El propietario (postgres) conserva sus privilegios.
revoke all on table
  public.configuracion,
  public.articulos,
  public.citas,
  public.consultas,
  public.testimonios,
  public.mensajes,
  public.push_subscriptions
from public, anon, authenticated, service_role;

-- ─── 2. service_role (rutas del servidor, lib/supabase.ts) ──────────────────
-- configuracion: lectura y upsert (INSERT + UPDATE) desde /api/admin/configuracion.
grant select, insert, update         on table public.configuracion      to service_role;
-- articulos: CMS completo, incluido borrado.
grant select, insert, update, delete on table public.articulos          to service_role;
-- citas: alta pública, cambio de estado; "cancelar" es UPDATE, no DELETE.
grant select, insert, update         on table public.citas              to service_role;
-- consultas: alta pública y cambio de estado.
grant select, insert, update         on table public.consultas          to service_role;
-- testimonios: moderación y borrado; el código no inserta testimonios.
grant select, update, delete         on table public.testimonios        to service_role;
-- mensajes: envío (cliente y abogado) y marcado de leídos por el admin.
grant select, insert, update         on table public.mensajes           to service_role;
-- push_subscriptions: upsert por endpoint y limpieza de caducadas.
grant select, insert, update, delete on table public.push_subscriptions to service_role;

-- ─── 3. authenticated (navegador: app/chat y ChatAdmin) ─────────────────────
-- SELECT: carga inicial del chat y eventos de Realtime (postgres_changes
-- solo entrega filas que el suscriptor puede leer).
grant select         on table public.mensajes to authenticated;
-- UPDATE solo de la columna leido: impide cambiar texto, remitente o cliente_id.
grant update (leido) on table public.mensajes to authenticated;

-- ─── 4. Políticas RLS de mensajes ───────────────────────────────────────────
-- Lectura: el cliente solo ve su conversación; el admin
-- (app_metadata.role = 'admin') ve todas, necesario para Realtime en ChatAdmin.
create policy mensajes_select_propios_o_admin
  on public.mensajes
  for select
  to authenticated
  using (
    cliente_id = (select auth.uid())
    or coalesce(((select auth.jwt()) -> 'app_metadata') ->> 'role', '') = 'admin'
  );

-- Actualización: el cliente solo puede marcar como leídos (leido = true) los
-- mensajes del abogado de su propia conversación. No puede tocar mensajes
-- de otros clientes ni los que él mismo envió. El admin no actualiza desde
-- el navegador: lo hace en el servidor con service_role.
create policy mensajes_cliente_marca_leidos
  on public.mensajes
  for update
  to authenticated
  using (
    cliente_id = (select auth.uid())
    and remitente = 'abogado'
  )
  with check (
    cliente_id = (select auth.uid())
    and remitente = 'abogado'
    and leido = true
  );

-- Sin políticas INSERT/DELETE en mensajes ni políticas en las otras 6 tablas:
-- con RLS activado y sin permisos, anon y authenticated no acceden a ellas.

-- ─── 5. Función de trigger ──────────────────────────────────────────────────
-- Nadie necesita llamarla directamente; el trigger se dispara igual.
revoke execute on function public.set_updated_at()
  from public, anon, authenticated, service_role;

commit;
