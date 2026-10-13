# Imperium Iuris

Sitio web y portal de clientes de un estudio jurídico: sitio público, blog,
agenda de citas, chat en tiempo real y panel de administración.

**Stack:** Next.js 15 (App Router) · TypeScript · Tailwind CSS · Supabase
(Auth, Postgres, Realtime, Storage) · Resend.

## Instalación local

Cada practicante debe hacer un **fork** del repositorio central y **clonar su
propio fork** (no el repositorio central).

👉 Sigue la guía **[docs/INSTALACION.md](docs/INSTALACION.md)** para configurar
el remoto `upstream`, preparar el entorno y trabajar mediante Pull Requests
hacia el repositorio central.

Resumen: fork → clonar tu fork → Node.js 22 → `npm ci` → copiar `.env.example` como `.env.local` →
completar las variables de Supabase DEV → `npm run dev` → http://localhost:3000.

## Scripts

| Comando | Uso |
|---|---|
| `npm run dev` | Servidor de desarrollo |
| `npm run build` | Compilación de producción |
| `npm run lint` | Revisión con ESLint |

## Seguridad

- No subas archivos `.env*` con valores reales.
- Usa solo el proyecto Supabase de desarrollo; nunca credenciales de producción.
- No ejecutes las migraciones ni el seed en el proyecto Supabase DEV compartido.
