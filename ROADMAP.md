# Roadmap — Geekstack Backend

Estado al 2026-07-08. Orden por prioridad; cada fase deja el sistema en un estado
funcional. Los ítems marcados **[BUG]** son defectos confirmados en código existente.

---

## Fase 0 — Recuperar y consolidar (bloqueante, hacer primero)

- [ ] **Reparar entorno Ruby**: el proyecto requiere Ruby 3.4.8 (`.tool-versions`)
      pero fue desinstalado de asdf (quedan 3.3.0, 3.3.11, 4.0.4).
      Opciones: `asdf install ruby 3.4.8` + `bundle install`, o migrar el proyecto
      a 3.4.x más reciente actualizando `.tool-versions` y `Gemfile.lock`.
- [ ] **Commitear el trabajo actual**: todo el código de MercadoPago, stock
      locations y rutas está **untracked** en `feature/spree-setup`. Un
      `git clean` accidental lo borraría. Incluir: `app/controllers/spree/`,
      `app/jobs/spree/`, `app/models/spree/payment_method/`, `app/services/`,
      `config/routes.rb`, `CLAUDE.md`, `ROADMAP.md`.
- [ ] Agregar `.idea/` y `.kamal/` al `.gitignore`.
- [ ] Decidir: ¿Kamal o Render? Hay `render.yaml` y `.kamal/` conviviendo;
      eliminar el que no se use.

## Fase 1 — Hardening MercadoPago (antes de recibir pagos reales)

- [ ] **[BUG] `ProcessPayment` nunca encuentra el pago**: busca
      `payments.find_by(response_code: mp_payment["preference_id"])`, pero la
      respuesta de `GET /v1/payments/:id` **no incluye** `preference_id`.
      Fix sugerido: localizar la orden por `external_reference` (ya se hace) y el
      pago por `payment_method` + estado pendiente, o guardar el `preference_id`
      en la preferencia MP como `metadata` y leerlo de ahí.
- [ ] **[BUG] Webhook posiblemente bloqueado por API key**: la ruta
      `POST /api/v3/store/mercado_pago/webhook` hereda de `BaseController`, que
      exige `X-Spree-Api-Key`. MercadoPago no envía ese header → verificar y, si
      aplica, saltarse esa autenticación **solo** en la acción `webhook`.
- [ ] **Validar firma del webhook** (`x-signature` + `x-request-id`, HMAC-SHA256
      con el secret del panel MP). Hoy cualquiera puede POSTear payment_ids.
      Mitigante actual: se re-consulta a MP con el access token, pero igual
      permite spam de jobs.
- [ ] **Pagos duplicados**: cada llamada a `/preference` crea un nuevo
      `Spree::Payment`. Invalidar (void) los pagos `checkout` previos del mismo
      método antes de crear otro.
- [ ] Robustecer los servicios HTTP: timeouts (`open_timeout`/`read_timeout`),
      rescate de `JSON::ParserError` y errores de red, logging estructurado del
      request/response de MP (sin credenciales).
- [ ] Registrar `Spree::LogEntry` en el payment con la respuesta de MP (auditoría).
- [ ] Webhook en desarrollo: túnel (ngrok/cloudflared) + setear
      `preferred_webhook_url`; probar flujo completo sandbox end-to-end.
- [ ] Página `/checkout/success` del front debe verificar el estado real de la
      orden contra el backend (no asumir pago aprobado por el redirect).
- [ ] Considerar `binary_mode: true` en la preferencia (evita estado "pending"
      si no se quiere manejar pagos en efectivo/transferencia diferida).
- [ ] Producción: mover credenciales MP a `Rails.credentials` o ENV
      (hoy: preferences en texto plano en BD), **rotar los tokens TEST**
      (se compartieron en chats), configurar back_urls y webhook_url reales,
      y activar `auto_return` (se activa solo al dejar de usar localhost).

## Fase 2 — Tests y calidad (deuda actual: 0 tests del código custom)

- [ ] Tests de `Geekstack::MercadoPago::CreatePreference` y `ProcessPayment`
      con WebMock/stubs (agregar gema `webmock`).
- [ ] Tests de controller para `mercado_pago_controller` (preference, webhook)
      y `stock_locations_controller`.
- [ ] Test de integración del checkout API v3 completo (cart → address →
      delivery → payment → complete) — es la documentación viva del flujo.
- [ ] CI (GitHub Actions): `bin/rails test` + `brakeman` + `bundle-audit` +
      `rubocop` en cada PR. Las gemas ya están en el Gemfile; solo falta el workflow.
- [ ] Fix N+1 en `StockLocationsController#index` (una query de Zone por
      location): cargar todas las zonas `description LIKE 'stock_location:%'` de
      una vez; agregar caché HTTP o de fragmento (los datos cambian poco).
- [ ] Extraer la convención `"stock_location:<id>"` a un método/constante
      (p. ej. `Geekstack::StoreZone`) en vez de strings repetidos.
- [ ] Seeds idempotentes para desarrollo: tiendas, zonas, métodos de envío,
      método de pago MP con credenciales dummy — hoy todo eso vive solo en la BD
      local y no es reproducible.

## Fase 3 — Actualizar Spree 5.4.2 → 5.5.x

Spree 5.5 (última: 5.5.4) trae cambios grandes orientados a este proyecto:
Admin API nueva con SDK TypeScript tipado, CLI oficial, Sales Channels,
Stock Reservations y Order Routing avanzado (útil para el despacho multi-tienda
de la Fase 4b). Son 500+ commits sobre 5.4 — hacer el upgrade **después** de
tener tests (Fase 2), que son la red de seguridad de la migración.

- [ ] Leer release notes y guía de upgrade oficial:
      https://github.com/spree/spree/releases/tag/v5.5.0
- [ ] Subir `spree`, `spree_admin`, `spree_emails` a `~> 5.5` (verificar que
      `spree_i18n` tenga release compatible), `bundle update`, correr
      migraciones nuevas (`rails spree:install:migrations && rails db:migrate`).
- [ ] Verificar que el código custom sobrevive: `PaymentMethod::MercadoPago`,
      controllers custom bajo `Spree::Api::V3::Store`, la convención de zonas
      `stock_location:<id>`, y las rutas en `Spree::Core::Engine.add_routes`.
- [ ] Correr la suite de integración del checkout (Fase 2) contra 5.5 y probar
      el front sin cambios — la API v3 Store no debería romper, confirmarlo.
- [ ] Evaluar adoptar lo nuevo de 5.5 donde reemplaza código propio:
      **Order Routing** podría sustituir/simplificar la lógica de zonas por
      tienda; **Sales Channels** si algún día hay más de un canal de venta.
- [ ] Evaluar migrar el front al SDK TypeScript oficial (`@spree/sdk`) en vez
      del cliente manual `src/lib/spree.ts`.

## Fase 4 — Completar los flujos de ecommerce

### 4a. Cuentas de usuario
- [x] Registro (`POST /customers`) y login JWT (`POST /auth/login`) funcionando.
- [ ] Recuperación de contraseña end-to-end (`POST /password_resets` existe;
      falta configurar mailer + página en el front).
- [ ] Configurar envío de emails reales (SMTP/Resend/Postmark) —
      `spree_emails` está instalado pero `action_mailer` apunta a `example.com`.
- [ ] Verificar/implementar asociación de carrito guest → usuario al hacer
      login (el front llama `PATCH /carts/:id/associate`; confirmar que la ruta
      existe en Spree 5.4 o implementarla).
- [ ] Direcciones guardadas del usuario (endpoints `customers/me/addresses`)
      para no re-tipear en cada compra.
- [ ] Evaluar `:confirmable` de Devise (confirmación de email) y `:lockable`
      (fuerza bruta) para `Spree::User`.

### 4b. Envío y retiro en tienda
- [x] Zonas por comuna vinculadas a cada tienda; endpoint de tiendas+comunas.
- [ ] Retiro en tienda como método explícito: un `ShippingMethod` por tienda
      (costo $0) restringido a su stock location, en lugar de un método genérico.
- [ ] Tarifas de despacho reales: hoy los calculadores son planos; definir
      precio por zona/comuna (FlatRate por zona) y umbral de envío gratis.
- [ ] Tiempos estimados de entrega por método (campo `estimated_transit_business_days`).
- [ ] Split de fulfillment: qué pasa si el stock está repartido entre tiendas
      (Spree crea múltiples shipments — decidir si se permite o se restringe a
      una tienda por orden).
- [ ] Validar dirección chilena: hacer `postal_code` opcional (en Chile casi no
      se usa) y validar comuna contra la zona de la tienda seleccionada.

### 4c. Pagos adicionales (post-MercadoPago)
- [ ] Transferencia bancaria manual (PaymentMethod tipo Check renombrado,
      con instrucciones en el front y confirmación manual en admin).
- [ ] Evaluar Webpay/Transbank o Fintoc según comisiones.

## Fase 5 — Producción

- [ ] Storage de imágenes: ActiveStorage usa `:local` en producción — en Render
      free el disco es **efímero**, las imágenes se pierden en cada deploy.
      Migrar a S3/Cloudflare R2 antes de lanzar.
- [ ] `action_mailer.default_url_options` y `Spree::Store#url` con dominio real.
- [ ] Revisar `db:seed` en cada deploy (`render-build.sh` lo corre siempre;
      confirmar idempotencia).
- [ ] CORS: revisar configuración para el dominio real del front.
- [ ] Backups de la BD (Render free no incluye; plan pago o pg_dump programado).
- [ ] Monitoreo básico: Sentry/Honeybadger para errores, healthcheck ya existe (`/up`).
- [ ] Rate limiting en endpoints públicos (rack-attack): login, registro, webhook.

## Fase 6 — Exponer un MCP del servicio

Objetivo: que agentes de IA (Claude, etc.) puedan operar sobre la tienda vía
Model Context Protocol. Son dos cosas distintas — decidir cuál se quiere (o ambas):

### 6a. MCP para desarrollo (trivial, se puede hacer ya)
- [ ] Conectar el MCP de documentación oficial de Spree al tooling de
      desarrollo (Claude Code / Cursor): endpoint `https://spreecommerce.org/docs/mcp`.
      No requiere código; se agrega como connector/`.mcp.json` del repo.

### 6b. MCP propio del backend (feature de producto)
Servidor MCP montado en la app Rails que expone la tienda como herramientas:
buscar productos, consultar stock por comuna, armar carrito, estado de órdenes.
Caso de uso: compras asistidas por agentes ("agentic commerce") y operación
interna (consultas del admin en lenguaje natural).

- [ ] Elegir gema: SDK oficial Ruby de MCP (`mcp`, mantenida por
      Anthropic/Shopify) o `fast-mcp` (integración Rails vía Rack middleware).
      Preferir transporte HTTP/SSE montado en una ruta (`/mcp`).
- [ ] Definir el set inicial de tools **read-only** (bajo riesgo):
      `search_products`, `get_product`, `stock_by_commune`, `store_locations`.
- [ ] Autenticación: API key dedicada por cliente MCP (no reutilizar la
      publishable key); scopes read vs write.
- [ ] Tools de escritura (fase 2 del MCP, requieren más cuidado):
      `create_cart`, `add_to_cart` — reutilizar los servicios/endpoints v3
      existentes por debajo, nunca lógica duplicada. El pago siempre queda
      fuera del MCP (el humano paga en MercadoPago).
- [ ] Tests de las tools + límite de rate (rack-attack sobre `/mcp`).
- [ ] Nota: hacer esto **después** del upgrade a 5.5 (Fase 3) — la Admin API
      nueva y el CLI pueden cambiar la forma recomendada de exponerlo, y evita
      construir sobre APIs que van a moverse.

## Fase 7 — Mejoras futuras (backlog)

- [ ] Búsqueda mejorada (pg_search o Meilisearch) — hoy solo Ransack `name_cont`.
- [ ] Promociones y cupones (Spree lo trae; falta configurar y exponer en front).
- [ ] Wishlist (endpoints v3 existen en el gem).
- [ ] Reviews de productos.
- [ ] Data feeds para Google Shopping (endpoint `feeds/:slug` ya existe).
- [ ] Webhooks de Spree hacia el front para revalidar caché de Next.js al
      cambiar productos.
- [ ] Boleta/factura electrónica (SII) — integración con Bsale/Lioren/OpenFactura.
- [ ] Multi-idioma completo del catálogo (Mobility ya está; falta traducir contenido).
