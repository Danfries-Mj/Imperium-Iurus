-- ════════════════════════════════════════════════════════════════════════════
-- seed.sql — Datos FICTICIOS para desarrollo              (SOLO DESARROLLO)
-- ════════════════════════════════════════════════════════════════════════════
-- Ningún dato procede de producción. Todo valor de contacto es
-- inequívocamente ficticio para que las pruebas no lleguen a nadie real:
--   · correos en example.com (dominio reservado por RFC 2606, no entrega correo);
--   · teléfonos y WhatsApp del rango +44 7700 900000 a +44 7700 900999,
--     que el regulador británico Ofcom reserva para obras de ficción y no
--     asigna a ninguna línea: los enlaces tel: y wa.me que genera la app
--     no llegan a ningún destinatario real;
--   · nombres y textos marcados con [PRUEBA].
--
-- configuracion: solo se siembra la clave contacto, para sustituir los
-- valores por defecto de lib/config-utils.ts (que contienen un WhatsApp y
-- un correo reales). El resto de claves usa CONFIG_DEFAULTS, sin datos de
-- contacto.
--
-- No se siembran mensajes, push_subscriptions ni usuarios: dependen de
-- auth.users o de navegadores reales y se generan con pruebas manuales.
--
-- NO EJECUTAR EN PRODUCCIÓN. Aborta sin cambios si faltan tablas, si M2 o
-- M3 no se han aplicado o si alguna de las tablas sembradas ya contiene
-- filas.
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
    raise exception 'SEED ABORTADA: faltan tablas en public: %. Aplica M1, M2 y M3 primero.', faltan;
  end if;

  if not exists (select 1 from pg_catalog.pg_policies p
                  where p.schemaname = 'public'
                    and p.tablename  = 'mensajes'
                    and p.policyname = 'mensajes_select_propios_o_admin') then
    raise exception 'SEED ABORTADA: falta la política mensajes_select_propios_o_admin en public.mensajes. Aplica M2 primero.';
  end if;

  if not exists (select 1 from pg_catalog.pg_publication_tables pt
                  where pt.pubname    = 'supabase_realtime'
                    and pt.schemaname = 'public'
                    and pt.tablename  = 'mensajes') then
    raise exception 'SEED ABORTADA: public.mensajes no está en la publicación supabase_realtime. Aplica M3 primero.';
  end if;

  if exists (select 1 from public.configuracion)
     or exists (select 1 from public.articulos)
     or exists (select 1 from public.citas)
     or exists (select 1 from public.consultas)
     or exists (select 1 from public.testimonios) then
    raise exception 'SEED ABORTADA: hay tablas con filas. La semilla solo se aplica una vez sobre un dev vacío. ¿Estás en producción?';
  end if;
end
$$;

-- ─── configuracion: contacto ficticio ───────────────────────────────────────
insert into public.configuracion (clave, valor) values
('contacto', '{
  "whatsapp": "+44 7700 900001",
  "whatsapp_mensaje": "[PRUEBA] Mensaje de WhatsApp del entorno de desarrollo",
  "telefono": "+44 7700 900000",
  "correo": "contacto@example.com",
  "direccion": "[PRUEBA] Dirección ficticia",
  "horas": "Lun-Vie 08:00-18:00",
  "emergencia": "[PRUEBA] Atención de urgencias ficticia"
}'::jsonb);

-- ─── articulos: 2 publicados y 1 borrador ───────────────────────────────────
insert into public.articulos (titulo, slug, categoria, resumen, contenido, tiempo_lectura, publicado) values
('[PRUEBA] Artículo publicado uno',
 'prueba-articulo-publicado-uno',
 'Derecho Penal',
 'Resumen ficticio del primer artículo de prueba.',
 '<p>Contenido ficticio de prueba. No constituye asesoría jurídica.</p><p>Segundo párrafo de ejemplo.</p>',
 '3 min',
 true),
('[PRUEBA] Artículo publicado dos',
 'prueba-articulo-publicado-dos',
 'Compliance',
 'Resumen ficticio del segundo artículo de prueba.',
 '<h2>Subtítulo de ejemplo</h2><p>Contenido ficticio de prueba.</p><ul><li>Elemento uno</li><li>Elemento dos</li></ul>',
 '5 min',
 true),
('[PRUEBA] Borrador sin publicar',
 'prueba-borrador-sin-publicar',
 'Derecho Penal',
 'Este artículo no debe aparecer en el blog público.',
 '<p>Borrador ficticio. Solo visible en el panel de administración.</p>',
 '2 min',
 false);

-- ─── testimonios: uno por estado ────────────────────────────────────────────
insert into public.testimonios (nombre, cargo, empresa, texto, calificacion, estado) values
('[PRUEBA] Cliente ficticio A', 'Gerente ficticio', 'Empresa Ficticia S.A.',
 'Testimonio ficticio aprobado: debe mostrarse en el sitio público.', 5, 'aprobado'),
('[PRUEBA] Cliente ficticio B', null, null,
 'Testimonio ficticio pendiente: solo visible en el panel.', 4, 'pendiente'),
('[PRUEBA] Cliente ficticio C', 'Cargo ficticio', null,
 'Testimonio ficticio rechazado: no debe mostrarse en el sitio público.', 2, 'rechazado');

-- ─── consultas: una por estado ──────────────────────────────────────────────
insert into public.consultas (nombre, correo, telefono, tipo_consulta, mensaje, confidencial, estado) values
('[PRUEBA] Persona ficticia uno',    'consulta.uno@example.com',    '+44 7700 900010', 'personal',
 'Consulta ficticia en estado nuevo.', true, 'nuevo'),
('[PRUEBA] Persona ficticia dos',    'consulta.dos@example.com',    '+44 7700 900011', 'empresarial',
 'Consulta ficticia en estado leído.', false, 'leido'),
('[PRUEBA] Persona ficticia tres',   'consulta.tres@example.com',   '+44 7700 900012', 'urgencia',
 'Consulta ficticia en estado respondido.', true, 'respondido'),
('[PRUEBA] Persona ficticia cuatro', 'consulta.cuatro@example.com', '+44 7700 900013', 'otro',
 'Consulta ficticia en estado archivado.', false, 'archivado');

-- ─── citas: una por estado, sin cliente vinculado ───────────────────────────
-- Fechas relativas a hoy para que siempre queden en el futuro.
insert into public.citas (nombre, correo, telefono, tipo_consulta, fecha, hora, mensaje, estado, cliente_id) values
('[PRUEBA] Persona ficticia cinco', 'cita.uno@example.com',  '+44 7700 900014', 'personal',
 current_date + 7,  '10:00', 'Cita ficticia pendiente.', 'pendiente', null),
('[PRUEBA] Persona ficticia seis',  'cita.dos@example.com',  '+44 7700 900015', 'empresarial',
 current_date + 8,  '11:30', 'Cita ficticia confirmada.', 'confirmada', null),
('[PRUEBA] Persona ficticia siete', 'cita.tres@example.com', '+44 7700 900016', 'urgencia',
 current_date + 9,  '15:00', null, 'cancelada', null);

commit;
