# Roadmap — Geekstack Backend

Estado al 2026-07-08. Orden por prioridad; cada fase deja el sistema en un estado
funcional. Los ítems marcados **[BUG]** son defectos confirmados en código existente.

**Proyecto relacionado (repo separado, no parte de este roadmap):** interfaz de
venta presencial (POS) en Next.js/TypeScript/Tailwind, consumiendo la Admin API
v3 de este backend (`/api/v3/admin/*` — órdenes, pagos, stock, clientes, etc.).
Locales físicos (`Spree::StockLocation`) 100% configurables desde el admin de
Spree, sin cantidad fija asumida por el POS. Aún en fase de análisis/roadmap
propio con Fable — este repo solo provee la API que consume.

---

## Fase 0 — Recuperar y consolidar (bloqueante, hacer primero)

- [x] **Reparar entorno Ruby**: Ruby 3.4.8 reinstalado vía asdf. Causa real
      del problema: asdf 0.20 no lee `.ruby-version` sin `legacy_version_file`
      en `~/.asdfrc` — se agregó un `.tool-versions` propio del proyecto
      (formato nativo de asdf) en vez de depender de config global del usuario.
- [x] **Commitear el trabajo actual**: código de MercadoPago, stock locations
      y rutas commiteados (`8f47392`).
- [x] **Decidir: ¿Kamal o Render?** Render es el target real (`render.yaml`
      configurado, 2 commits de tuning). Se eliminó el scaffold de Kamal
      (`config/deploy.yml`, `bin/kamal`, `.kamal/`, gem `kamal` del Gemfile) —
      nunca se configuró (IP placeholder `192.168.0.1`).

## Fase 1 — Hardening MercadoPago (antes de recibir pagos reales)

- [x] **[BUG corregido] `ProcessPayment` nunca encontraba el pago**: ahora
      matchea por `order` (via `external_reference`) + pago más reciente en
      estado `checkout`/`pending` de ese payment method, en vez de un
      `preference_id` que el recurso Payment de MP no trae.
- [x] **[BUG corregido] Webhook bloqueado por API key**: se agregó
      `skip_before_action :authenticate_api_key!, only: :webhook`.
- [x] **Validar firma del webhook**: HMAC-SHA256 sobre
      `"id:{data.id};request-id:{x-request-id};ts:{ts};"` contra
      `preferred_webhook_secret` (nueva preference del payment method). Si el
      secret no está seteado, deja pasar con warning en log — **falta setear
      el secret real en producción** (Mercado Pago → Tus integraciones →
      Webhooks → Configurar notificación).
- [x] **Pagos duplicados**: `create_preference` voidea los pagos `checkout`
      previos del mismo payment method antes de crear uno nuevo.
- [x] Robustecer los servicios HTTP: timeouts (`open_timeout`/`read_timeout`),
      rescate de `JSON::ParserError` y errores de red en ambos servicios.
- [x] **[BUG corregido, no listado originalmente]** `may_<evento>?` no existe
      en esta versión de Spree (es `can_<evento>?`, gema `state_machines` no
      `state_machine`) — afectaba `payment.complete!`/`failure!`/`void!` y
      `order.next!`, silenciosamente los dejaba sin ejecutar nunca.
- [x] **[BUG corregido, no listado originalmente]** Un pago rechazado/cancelado
      en MP seguía en estado `checkout` en Spree (nunca pasó por
      `pending`/`processing`), así que `failure!` nunca era una transición
      válida — se cambió a `void!`.
- [x] Registrar `Spree::LogEntry` en el payment con la respuesta de MP (auditoría):
      `payment.log_entries.create!(details: mp_payment.to_json)` en `ProcessPayment#call`.
- [ ] Webhook en desarrollo: túnel (ngrok/cloudflared) + setear
      `preferred_webhook_url`; probar flujo completo sandbox end-to-end.
- [ ] Página `/checkout/success` del front debe verificar el estado real de la
      orden contra el backend (no asumir pago aprobado por el redirect).
- [ ] Considerar `binary_mode: true` en la preferencia (evita estado "pending"
      si no se quiere manejar pagos en efectivo/transferencia diferida).
- [ ] Producción: mover credenciales MP a `Rails.credentials` o ENV
      (hoy: preferences en texto plano en BD), **rotar los tokens TEST**
      (se compartieron en chats), configurar back_urls, webhook_url y
      webhook_secret reales, y activar `auto_return` (se activa solo al dejar
      de usar localhost).

## Fase 2 — Tests y calidad (deuda actual: 0 tests del código custom)

- [x] Tests de `Geekstack::MercadoPago::CreatePreference` y `ProcessPayment`
      con WebMock (gema agregada al Gemfile). 15 tests cubriendo payload,
      auto_return, errores de red/JSON, y el matching de pagos corregido.
- [x] Tests de controller para `mercado_pago_controller` (preference, webhook,
      firma, pagos duplicados) y `stock_locations_controller`. Ver
      `test/support/spree_test_helpers.rb` para los builders reutilizables de
      store/order/producto/stock/zona de test.
- [x] Test de integración del checkout API v3 completo (cart → item →
      address → delivery rate → preferencia MercadoPago → webhook →
      order completado): `test/integration/api_v3_checkout_flow_test.rb`.
      Documenta hallazgos: no existe `GET fulfillments#index` (los fulfillments
      vienen embebidos en el payload del carrito), el `id` del carrito para las
      rutas es el prefijado (`cart["id"]`, no `cart["number"]`), y Spree
      geocodea la dirección de envío vía Nominatim en un job en background
      (hay que stubearlo con WebMock en tests que usan `perform_enqueued_jobs`).
- [x] CI (GitHub Actions): ya existía `.github/workflows/ci.yml` (scaffold de
      `rails new`) con `bin/rails test` + `brakeman` + `bundler-audit` +
      `rubocop`, con Postgres real. No se creó nada nuevo, solo se verificó.
- [x] Fix N+1 en `StockLocationsController#index`: una sola query de Zone con
      `includes(zone_members: :zoneable)` en vez de una query por location.
- [x] Extraída la convención `"stock_location:<id>"` a
      `Geekstack::StoreZone.description_for`/`.location_id_from`.
- [x] Seeds idempotentes para desarrollo (`db/seeds.rb`): store GeekStack,
      IVA 19%, StockLocations Providencia/La Florida + sus zonas de despacho
      (comunas reales), zona nacional Chile, shipping methods (despacho por
      tienda, envío nacional, retiro en tienda), Transferencia bancaria y
      MercadoPago (sin credenciales — hay que setearlas después). Nota: Carmen
      (la fuente de datos de `Spree::Seeds::States`) solo modela Chile a nivel
      de región, no de comuna — las comunas se crean como `Spree::State` planos,
      igual que ya hacía `create_test_stock_location_with_commune` en tests.
- [x] Fixeado el warning de deprecación `Spree::DefaultPrice`: `create_test_product`
      ahora usa `variant.set_price("CLP", amount)` y `add_line_item` lee
      `variant.price_in("CLP").amount` en vez de asignar/leer `price:` directo.
- [x] `bundle-audit` corregido: puma, rails-html-sanitizer, spree (CVE de CSV
      injection, parchado en 5.4.3+), websocket-driver, devise, msgpack
      actualizados a sus versiones parchadas dentro de la línea 5.4.x
      (`gem "spree", "~> 5.4.2"` — pineado a propósito, ver Fase 3).
      `bundle exec bundle-audit check` → "No vulnerabilities found".

## Fase 3 — Actualizar Spree 5.4.2 → 5.5.x

Spree 5.5 (última: 5.5.4) trae cambios grandes orientados a este proyecto:
Admin API nueva con SDK TypeScript tipado, CLI oficial, Sales Channels,
Stock Reservations y Order Routing avanzado (útil para el despacho multi-tienda
de la Fase 4b). Son 500+ commits sobre 5.4 — hacer el upgrade **después** de
tener tests (Fase 2), que son la red de seguridad de la migración.

- [x] Leer release notes y guía de upgrade oficial (5.4→5.5): sin cambios que
      rompan nuestro código, salvo dos deprecaciones menores (ver abajo).
- [x] Subida `spree`/`spree_admin`/`spree_emails` a `~> 5.5.4` (`spree_i18n`
      5.3.3 es compatible, acepta `spree_core >= 5.4.0.alpha`). `bundle update`
      solo movió los gems de Spree + `net-imap` (dependencia transitiva).
- [x] Migraciones nuevas aplicadas (`spree:install:migrations && db:migrate`,
      19 migraciones: Channels, Order Routing Rules, Stock Reservations,
      Variant Media, columnas nuevas en orders/products/stock_locations, etc.)
      + backfills obligatorios (`spree:upgrade` → `spree:channels:upgrade` →
      `spree:search:reindex`, en ese orden — si se corre el reindex antes del
      backfill de canales, todos los productos quedan con `store_id NULL` y
      desaparecen del catálogo).
- [x] Agregado el job programado que pide la guía oficial de upgrade:
      `Spree::StockReservations::ExpireJob` cada minuto en `config/recurring.yml`
      (Solid Queue) — si no se agenda, las reservas de stock expiradas del
      checkout nunca se limpian.
- [x] Verificado que el código custom sobrevive: `PaymentMethod::MercadoPago`
      (el cambio de serialización del atributo `type` en la Admin API es solo
      de cara al wire, no toca la columna STI real), controllers custom bajo
      `Spree::Api::V3::Store`, la convención de zonas `stock_location:<id>`, y
      el test de integración del checkout completo (Fase 2) — todo pasa sin
      cambios. Único ajuste real: `Spree::Product#stores=` está deprecado
      (ahora `store=` singular) — actualizado en `spree_test_helpers.rb`.
      No usamos Order Routing custom (Coordinator/Packer/Prioritizer), así que
      el cambio de estrategia por defecto en 5.5 no nos afecta.
- [x] `db/seeds.rb` verificado idempotente contra el schema post-upgrade.
      Brakeman, `bundle-audit` y RuboCop limpios.
- [ ] Evaluar adoptar lo nuevo de 5.5 donde reemplaza código propio:
      **Order Routing** podría sustituir/simplificar la lógica de zonas por
      tienda; **Sales Channels** si algún día hay más de un canal de venta.
- [ ] **Frontend (repo separado)**: subir `@spree/sdk` a `1.1+` — requerido por
      la guía oficial de upgrade para consumidores JS. Evaluar migrar el
      cliente manual `src/lib/spree.ts` al SDK TypeScript oficial.

## Fase 3b — Actualizar Spree 5.5.4 → 5.6.0

Salió mientras se cerraba la Fase 3. Mismo proceso cuidadoso, encadenado
inmediatamente después del 5.4→5.5 (con tests + Brakeman/bundler-audit/RuboCop
como red de seguridad de ambos saltos).

- [x] Leído el release de v5.6.0 en GitHub y la guía oficial 5.5→5.6: el cambio
      grande es que `Spree::Promotion` y `Spree::PaymentMethod` pasan de
      many-to-many (`stores`) a `belongs_to :store` singular — mismo patrón que
      `Spree::Product` en 5.5. Infra: Redis deja de ser requerido por defecto.
- [x] Subida `spree`/`spree_admin`/`spree_emails` a `~> 5.6.0`. `bundle update`
      solo movió Spree + transitivas (`alba`, `csv`, `phonelib`, `rbs`).
- [x] Migraciones nuevas aplicadas (`spree:install:migrations && db:migrate`,
      11 migraciones: `store_id` en role_users/taxons/promotions/payment_methods,
      `products_count` en taxons, `channel_id` en api_keys, preorder en variants,
      fingerprint en credit cards, etc.).
- [x] Backfill con `spree:upgrade` (idempotente, 5 pasos: role_users store_id →
      `populate_single_store_associations` [promotions+payment methods] →
      taxons store_id → taxons products_count → product tag tenants).
      Verificado en consola: `Spree::PaymentMethod::MercadoPago`/`Check`/
      `StoreCredit` quedaron con `store_id` correcto.
- [x] Único ajuste de código real: `Spree::PaymentMethod#stores=`/`Check#stores=`
      en `db/seeds.rb` y `spree_test_helpers.rb` → `store:`/`store=` singular
      (el shim viejo sigue funcionando pero con deprecation warning; ver
      CLAUDE.md). No usamos `Spree::Promotion` custom todavía, sin impacto ahí.
- [x] 26/26 tests pasan, Brakeman 0 warnings, `bundle-audit` limpio, RuboCop
      sin offenses.
- [ ] **Frontend (repo separado)**: subir `@spree/sdk` a `1.2+` (requerido por
      la guía 5.6, reemplaza el requisito `1.1+` de la Fase 3).

## Fase 4 — Completar los flujos de ecommerce

### 4a. Cuentas de usuario
- [x] Registro (`POST /customers`) y login JWT (`POST /auth/login`) funcionando.
- [x] **RUT chileno obligatorio y único en `Spree::User`**: columna `rut` +
      índice único, `ChileanRutValidator` (formato + dígito verificador módulo
      11), normalización automática antes de guardar (quita puntos/espacios,
      agrega guión si falta, mayúscula en "K") vía decorator del modelo.
      Aceptado y expuesto en `POST/PATCH /api/v3/store/customers` y en la
      Admin API (`/api/v3/admin/customers`), serializado en ambas respuestas.
      Primer uso en el repo del patrón de decorators de Spree (`*_decorator.rb`,
      cargados por el glob en `config/application.rb`) — ver CLAUDE.md.
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

### 4d. Soporte backend para el POS presencial (repo separado, Next.js)
Tanda A del análisis de Fable (ver nota al inicio del roadmap). Todo verificado
por curl end-to-end contra datos reales (producto, stock, dos locales).

- [x] Método de pago "Efectivo": segunda instancia de `Spree::PaymentMethod::Check`
      con `auto_capture: true` (mismo mecanismo que "Transferencia bancaria").
- [x] Roles `cashier`/`supervisor` acotados (`Spree::PermissionSets::PosCashier`/
      `PosSupervisor`) — allow-list explícito, sin `:manage` amplio. Requirió
      decorar `Admin::OrdersController#authorize_resource!`: por defecto
      colapsa `complete`/`cancel`/`approve`/`resume`/`resend_confirmation` en
      una sola acción `:update`, lo que hacía imposible dar "completar" sin
      dar también "cancelar".
- [x] `POST /orders` con `preferred_stock_location_id` ya funcionaba, pero
      **no bastaba solo con el parámetro**: sin una regla de Order Routing
      (`Spree::OrderRouting::Rules::PreferredLocation`) para el canal, el
      reducer siempre cae al stock location default de la tienda. Se creó
      esa regla para el canal "POS" en los seeds.
- [x] Venta anónima (sin email) para el canal POS (`Spree::OrderDecorator#require_email`).
      Encontró un segundo gap real: sin `ship_address`, Spree no calcula
      tarifas de envío (son por zona) y la orden nunca completa — se resolvió
      asignando automáticamente la dirección del propio stock location como
      `ship_address`/`bill_address` (con `quick_checkout: true` para saltar
      nombre/calle/código postal).
- [x] Idempotencia (`Idempotency-Key`) — ya viene en `spree_api` de fábrica,
      solo se verificó.
- [x] Sesión JWT — sin cambios, ya calza (access 5 min + refresh 30 días
      rotando vía cookie httpOnly). Importante para el POS: el refresh es
      **cookie, no body** — necesita `credentials: 'include'`.
- [x] CORS (`rack-cors`) scoped a `/api/v3/admin/*`, `credentials: true`,
      orígenes configurables por `POS_CORS_ORIGINS` (vacío hasta tener el
      origen real del POS).
- [x] `barcode` de `Spree::Variant` habilitado en Ransack (ya existía la
      columna, faltaba el whitelist) para el lookup por código de barras.
- [ ] **Bloqueado en Fable**: falta el origen de desarrollo del POS para
      completar `POS_CORS_ORIGINS`.
- [ ] Efectivo real vs. redondeo de vuelto: el cálculo de vuelto queda del
      lado del POS, el backend solo registra el monto exacto — sin acción
      pendiente acá salvo que cambie el acuerdo.

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
