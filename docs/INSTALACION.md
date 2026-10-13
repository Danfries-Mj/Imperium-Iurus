# Instalación local — Imperium Iuris

Guía para trabajar en el proyecto desde **tu propio fork** y ejecutarlo en tu
computadora usando el **Supabase de desarrollo (DEV) compartido**. No necesitas
crear bases de datos ni ejecutar migraciones: el DEV ya está preparado.

> ⚠️ **Nunca uses credenciales, correos ni datos de producción.**
> Todo lo que hagas localmente se guarda en el Supabase DEV que comparten
> todos los practicantes.

En los comandos de esta guía, sustituye `TU_USUARIO` por **tu** nombre de
usuario de GitHub.

## 1. Requisitos

| Herramienta | Versión | Descarga |
|---|---|---|
| Node.js | **22** (mínimo 20) | https://nodejs.org (versión 22 LTS) |
| Git | Cualquier versión reciente | https://git-scm.com |
| Cuenta de GitHub | — | https://github.com |

Comprueba la instalación:

```bash
node -v
```

```bash
git --version
```

`node -v` debe mostrar `v22.x.x`. Si usas un gestor de versiones, el
repositorio incluye un archivo `.nvmrc` con la versión 22: ejecuta `nvm use`
(nvm en macOS/Linux) o `nvm use 22` (nvm-windows, que no lee `.nvmrc`).

## 2. Obtener el código: fork, clon y `upstream`

### 2.1. Haz un fork del repositorio central

1. Abre https://github.com/JoelVelasqueZz/Imperium-Iurus
2. Pulsa **Fork** y créalo en tu cuenta (`TU_USUARIO/Imperium-Iurus`).

**Visibilidad del fork:** se recomienda que sea **privado** cuando GitHub lo
permita. GitHub no deja cambiar la visibilidad de un fork: el fork de un
repositorio privado es privado, pero el de un repositorio público es siempre
público. Si tu fork es público, cualquier archivo que subas por error será
visible para todo el mundo.

### 2.2. Clona **tu** fork (no el repositorio central)

```bash
git clone https://github.com/TU_USUARIO/Imperium-Iurus.git
```

```bash
cd Imperium-Iurus
```

### 2.3. Configura el repositorio central como `upstream`

```bash
git remote add upstream https://github.com/JoelVelasqueZz/Imperium-Iurus.git
```

```bash
git remote -v
```

Debes ver dos remotos:

| Remoto | Apunta a | Uso |
|---|---|---|
| `origin` | `TU_USUARIO/Imperium-Iurus` (tu fork) | Subir tus ramas |
| `upstream` | `JoelVelasqueZz/Imperium-Iurus` (central) | Traer los cambios del proyecto |

## 3. Instalar dependencias

```bash
npm ci
```

Usa `npm ci` (no `npm install`): instala exactamente las versiones de
`package-lock.json`.

> No ejecutes `npm audit fix`, `npm update` ni instales paquetes nuevos sin
> autorización: cambian versiones y pueden romper el proyecto.

## 4. Crear `.env.local`

Copia la plantilla:

- **Windows (PowerShell):** `Copy-Item .env.example .env.local`
- **macOS / Linux / Git Bash:** `cp .env.example .env.local`

`.env.local` está incluido en `.gitignore`, así que Git no lo subirá con un
`git add` normal. **Nunca lo subas, compartas ni lo muestres en capturas.**

> `.gitignore` solo evita que se añadan archivos nuevos. **No protege un
> archivo que ya se haya subido**: borrarlo en un commit posterior no lo
> elimina del historial ni de las copias que otros ya tengan. Si alguna vez
> subes por error un archivo `.env` o una clave, **avisa de inmediato al
> responsable del proyecto** para que revoque las claves.

## 5. Configurar las variables de Supabase DEV

El responsable del proyecto te entregará, por un canal privado, los valores de:

| Variable | Qué es |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | URL del proyecto Supabase DEV |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Clave pública del proyecto DEV |
| `SUPABASE_SERVICE_ROLE_KEY` | Clave **secreta** del servidor |

Pégalos en `.env.local`, después del `=` y sin comillas. El resto de variables
ya traen valores seguros para desarrollo; **no las cambies**.

Sobre `SUPABASE_SERVICE_ROLE_KEY`:

- Da acceso total a la base de datos DEV: trátala como una contraseña.
- No la pegues en chats, issues, commits ni capturas.
- Si crees que se ha filtrado, avisa al responsable de inmediato para revocarla.

### Un único Supabase DEV para todos

Todos los practicantes usan **el mismo proyecto Supabase DEV**. Lo que crees,
edites o borres desde tu entorno local lo verán los demás. Por eso:

- **No ejecutes las migraciones** (`supabase/migrations/`) **ni el seed**
  (`supabase/seed.sql`): ya están aplicados.
- **No modifiques el esquema compartido** (tablas, políticas, permisos,
  funciones, buckets) **sin autorización** del responsable.
- No ejecutes SQL ni los archivos de `docs/sql/`.

### Correos de agenda (`DISABLE_APPOINTMENT_EMAILS`)

En `.env.example` la línea `# DISABLE_APPOINTMENT_EMAILS=true` está comentada.
Su objetivo es que la agenda no intente enviar correos durante `npm run dev`,
pero **no tendrá ningún efecto hasta que la implementación correspondiente
(en `app/api/appointments/route.ts`) esté incluida en el código que estás
usando**. Mientras no lo esté, la variable se ignora aunque la descomentes.
Si tienes dudas, pregunta al responsable.

En cualquier caso, la clave de Resend de la plantilla es ficticia, así que no
se envía ningún correo real.

## 6. Ejecutar la aplicación

```bash
npm run dev
```

Abre **http://localhost:3000**. Usa `localhost`, no `127.0.0.1`: las cookies
de sesión dependen del nombre del host.

## 7. Comprobaciones básicas

1. **Portada:** `http://localhost:3000` carga sin errores.
2. **Blog:** `/blog` muestra artículos de prueba cuyo título empieza por
   `[PRUEBA]`. Los borradores no aparecen.
3. **Páginas públicas:** `/nosotros`, `/servicios`, `/contacto` y `/agenda` cargan.
4. **Inicio de sesión de cliente:** en `/login`, entra con el **correo y la
   contraseña** de la cuenta de prueba que te entreguen (el inicio de sesión
   con Google no está configurado en DEV). Al entrar vuelves a la portada;
   después abre `/mis-citas`, que debe cargar (vacía si tu cuenta no tiene citas).
5. **Panel admin** (solo si te dieron una cuenta admin): `/admin/login` lleva
   a `/admin/agenda`.

## 8. Flujo de trabajo con Git

Reglas:

- **Nunca trabajes directamente sobre `main`**, ni en tu fork ni en el
  repositorio central. Usa una rama por tarea.
- Tus cambios llegan al proyecto **solo mediante Pull Requests** desde tu fork
  hacia la rama `main` del repositorio central.
- **No despliegues por tu cuenta.** La rama `main` del repositorio central es la
  que se publica en producción; solo el responsable fusiona los Pull Requests.
  No conectes tu fork a Vercel ni a otro servicio de hosting.

### 8.1. Empezar una tarea

Antes de crear la rama, sincroniza tu `main` (ver 8.3). Después:

```bash
git switch main
```

```bash
git switch -c tipo/descripcion-corta
```

Ejemplos de nombre de rama: `fix/formulario-contacto`, `docs/guia-blog`,
`feat/filtro-citas`.

### 8.2. Guardar y subir tus cambios

Añade los archivos uno por uno (evita `git add .`, para no incluir archivos
que no corresponden a la tarea) y revisa antes de confirmar:

```bash
git status
```

```bash
git add ruta/del/archivo
```

```bash
git commit -m "fix: descripción breve del cambio"
```

```bash
git push -u origin tipo/descripcion-corta
```

### 8.3. Sincronizar tu fork con `upstream/main`

Hazlo antes de empezar cada tarea y cuando el responsable te lo indique:

```bash
git fetch upstream
```

```bash
git switch main
```

```bash
git merge --ff-only upstream/main
```

```bash
git push origin main
```

Si `git merge --ff-only` falla, es que tu `main` tiene commits propios (no
debería): no lo fuerces y consulta al responsable.

Para llevar esos cambios a la rama en la que estás trabajando:

```bash
git switch tipo/descripcion-corta
```

```bash
git merge main
```

Si después de sincronizar cambió `package-lock.json`, vuelve a ejecutar
`npm ci`.

### 8.4. Abrir un Pull Request

1. En GitHub, abre tu fork y pulsa **Compare & pull request** (o
   **Contribute → Open pull request**).
2. Comprueba la dirección del PR:
   - **base repository:** `JoelVelasqueZz/Imperium-Iurus` · **base:** `main`
   - **head repository:** `TU_USUARIO/Imperium-Iurus` · **compare:** tu rama
3. Describe qué cambiaste y cómo lo probaste.
4. Revisa en la pestaña **Files changed** que no aparezca ningún archivo `.env`
   ni ninguna clave.

## 9. Reglas del entorno compartido

- No ejecutes migraciones, seed ni SQL (ver sección 5).
- No borres ni modifiques datos creados por otras personas.
- Usa solo datos ficticios (correos `@example.com`, nombres inventados).
- No uses correos ni teléfonos reales en formularios.
- No cambies la configuración del proyecto Supabase.

## 10. Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| Error `supabaseUrl is required` o `supabaseKey is required` | Falta alguna de las tres variables de Supabase en `.env.local` |
| `TypeError: Invalid URL` al arrancar | `NEXT_PUBLIC_SUPABASE_URL` mal copiada (debe empezar por `https://`) |
| Inicias sesión pero la página vuelve al login | Estás usando `127.0.0.1`; usa `localhost:3000` |
| `Port 3000 is in use` | Cierra el otro proceso y vuelve a ejecutar `npm run dev`, para seguir usando `localhost:3000` |
| Cambiaste `.env.local` y no se nota | Detén el servidor (Ctrl+C) y vuelve a ejecutar `npm run dev` |
| `git push` rechazado en `main` | Estás trabajando en `main`: crea una rama (sección 8.1) |
| `fatal: remote upstream already exists` | Ya configuraste `upstream`; compruébalo con `git remote -v` |

Para cualquier otro error de Supabase, avisa al responsable del proyecto en
lugar de intentar arreglarlo en la base de datos.
