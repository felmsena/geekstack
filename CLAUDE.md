# Geekstack — Backend Spree (headless)

Tienda chilena de juegos de mesa y productos geek. Este repo es **solo el backend**:
Rails 8.1 + Spree 5.6.x expuesto vía API v3. El frontend es un proyecto Next.js
separado en `/Users/felipe/GIT/Personal/NextJS/geekstack` (cliente API en
`src/lib/spree.ts` de ese repo) — **pendiente**: ese repo debe subir `@spree/sdk`
a `1.2+` para ser compatible con esta versión de Spree.

## Stack y entorno

- Ruby 3.4.8 (asdf, ver `.tool-versions` — asdf 0.20 no lee `.ruby-version` sin
  `legacy_version_file` en `~/.asdfrc`, por eso el `.tool-versions` del proyecto)
  · Rails 8.1 · PostgreSQL
- Spree 5.6.x — **pineado a propósito** (`~> 5.6.0`, no `~> 5.6`) para que un
  `bundle update` suelto no arrastre la migración a la próxima minor sin
  decidirlo. `spree_admin`, `spree_emails`, `spree_i18n` + Devise.
- **Stock Reservations** (desde 5.5): retiene stock durante el checkout.
  Requiere un job programado (`Spree::StockReservations::ExpireJob`, cada
  minuto) o las reservas expiradas se acumulan sin limpiarse — ya está en
  `config/recurring.yml`. No customizamos Order Routing (Coordinator/Packer/
  Prioritizer), así que el cambio de estrategia por defecto en 5.5 no afecta
  código propio.
- `Spree::Product#stores=`/`#stores` (deprecado desde 5.5) y, desde **5.6**,
  también `Spree::Promotion#stores=`/`#stores` y **`Spree::PaymentMethod#stores=`/`#stores`**
  — los tres pasaron de many-to-many a `belongs_to :store` singular
  (`store`/`store_id`). El setter viejo (`stores:`/`stores=`) sigue funcionando
  vía un shim de compatibilidad (`Spree::LegacyMultiStoreSupport`, se elimina
  en 6.0) pero emite `Spree::Deprecation.warn`; usar siempre `store:`/`store=`
  singular en código nuevo. Multi-store real requiere la gema
  `spree_multi_store`, que no usamos. El upgrade a 5.6 corrió
  `spree:upgrade` (que incluye `spree:upgrade:populate_single_store_associations`)
  para backfillear `store_id` en payment methods/promotions existentes desde
  las tablas join legacy — necesario una sola vez, después de las migraciones.
- Solid Queue / Solid Cache / Solid Cable (todo en Postgres)
- Deploy: Render free tier (`render.yaml`) — 512 MB RAM, por eso
  `WEB_CONCURRENCY=1` y `RAILS_MAX_THREADS=2`. No subir esos valores sin cambiar de plan.
- **`config/credentials.yml.enc` está pineado a la `master.key` local de este
  repo.** No re-encriptar el archivo con una master key distinta (p.ej. para
  probar un deploy alternativo como Openship) — eso rompe `bin/rails` para
  cualquiera que tenga la key original, con `ActiveSupport::MessageEncryptor::InvalidMessage`.
  Si un entorno de deploy nuevo necesita las credenciales, pásale la misma
  `master.key` vía `RAILS_MASTER_KEY` (env var), no generes un `.enc` nuevo.
- Tests: Minitest (`bin/rails test`) + WebMock (mockea las llamadas HTTP a
  MercadoPago, ver `test/support/spree_test_helpers.rb` para los builders de
  store/order/producto/stock de test). Brakeman, bundler-audit y RuboCop
  (rails-omakase) están en el Gemfile y corren en CI (`.github/workflows/ci.yml`).

```sh
bin/rails server          # backend en :3000 (el front corre en :3001)
bin/rails test            # minitest
bin/rails runner '...'    # consultas puntuales contra la BD de desarrollo
```

## Configuración de la tienda (datos, no código)

- Moneda `CLP`, locale por defecto `es-CL`, `supported_locales` debe incluir
  **ambos** `es` y `es-CL` — si falta uno el checkout falla con 422
  "Locale is not supported by this store".
- Dos `Spree::StockLocation` (Providencia y La Florida). Cada tienda se vincula a
  una `Spree::Zone` mediante la convención `zone.description == "stock_location:<id>"`,
  encapsulada en `Geekstack::StoreZone` (`description_for`/`location_id_from` —
  no hardcodear el string en código nuevo). Los miembros de la zona son las
  comunas (states de Chile) donde esa tienda despacha, tomadas del set
  completo de 346 comunas que `db/seeds.rb` siembra desde
  `Geekstack::ChileRegions` (cada `Spree::State` de Chile tiene `region` con
  el nombre de su región — ver gotcha de `Spree::Seeds::States` más abajo
  sobre por qué esto no viene de Spree/Carmen). El endpoint custom
  `GET /api/v3/store/stock_locations` expone tienda + comunas.
  Para agregar una tienda: crear StockLocation + Zone con esa descripción + ShippingMethod.
- IVA 19% configurado como tax rate por defecto.
- **Todo `Spree::User` requiere un RUT chileno único** (`rut`, índice único).
  Validado con `ChileanRutValidator` (formato + dígito verificador módulo 11)
  y normalizado antes de guardar (`Spree::UserDecorator#normalize_rut`: quita
  puntos/espacios, agrega el guión si falta, sube "k" a "K") — así
  `"12.345.678-5"`, `"12345678-5"` y `"123456785"` terminan siendo el mismo
  registro. Se acepta/expone en `POST/PATCH /api/v3/store/customers` y en
  `/api/v3/admin/customers` (ambos decorados para permitir el param; el
  serializer base `Spree::Api::V3::CustomerSerializer` lo expone en ambas
  respuestas, ya que el admin serializer hereda del store). No aplica a
  `Spree::AdminUser` (staff interno), solo a clientes.

## Decorators (patrón para extender clases de Spree)

Primer uso en este repo (RUT de usuario). Un archivo con `_decorator` en el
nombre bajo `app/**` se carga explícitamente por un glob en
`config/application.rb` (mismo mecanismo que usa `spree_core` internamente),
**fuera** de las reglas normales de Zeitwerk. Por eso el archivo debe definir
igual el módulo/clase que Zeitwerk esperaría por su ruta (p. ej.
`app/models/spree/user_decorator.rb` → `module Spree::UserDecorator`) aunque
después se use `prepend`/`class_eval` para modificar la clase real — si el
archivo no define esa constante, Rails revienta con
`Zeitwerk::NameError: expected file ... to define constant ...` al bootear.

## Código custom (todo lo que no es Spree vanilla)

| Ruta | Qué es |
|---|---|
| `app/models/spree/user_decorator.rb` | Normaliza y valida el RUT chileno en `Spree::User` |
| `app/validators/chilean_rut_validator.rb` | Formato + dígito verificador (módulo 11) de un RUT |
| `app/controllers/spree/api/v3/{store,admin}/customers_controller_decorator.rb` | Permiten el param `rut` en alta/edición de clientes |
| `app/serializers/spree/api/v3/customer_serializer_decorator.rb` | Expone `rut` en las respuestas de cliente |
| `app/models/spree/payment_method/mercado_pago.rb` | PaymentMethod sin source (`source_required? == false`); credenciales MP como `preferences` |
| `app/services/geekstack/mercado_pago/create_preference.rb` | POST a `api.mercadopago.com/checkout/preferences`, devuelve `init_point` |
| `app/services/geekstack/mercado_pago/process_payment.rb` | Consulta `/v1/payments/:id` y actualiza el pago Spree |
| `app/jobs/spree/mercado_pago/webhook_job.rb` | Procesa webhooks en background |
| `app/controllers/spree/api/v3/store/mercado_pago_controller.rb` | `POST carts/:cart_id/mercado_pago/preference` y `POST mercado_pago/webhook` |
| `app/controllers/spree/api/v3/store/stock_locations_controller.rb` | Tiendas + comunas para el front |
| `app/models/spree/seeds/states_decorator.rb` | Evita que Spree siembre regiones de Chile (choca con nuestras comunas) |
| `app/services/geekstack/chile_regions.rb` | Las 346 comunas oficiales agrupadas por sus 16 regiones — fuente de `db/seeds.rb` |
| `app/models/spree/permission_sets/pos_cashier.rb`, `pos_supervisor.rb` | Roles acotados para el POS presencial (ver ROADMAP Fase 4d) |
| `app/models/spree/order_decorator.rb` | Venta POS anónima (sin email) + dirección de retiro auto-asignada desde el stock location |
| `app/models/spree/variant_decorator.rb` | Habilita `barcode` en Ransack (búsqueda por código de barras del POS) |
| `app/controllers/spree/api/v3/admin/orders_controller_decorator.rb` | No colapsa `complete`/`cancel`/`approve`/`resume` en una sola acción `:update` de CanCan |
| `app/services/geekstack/pos_channel.rb` | Código del `Spree::Channel` "POS", compartido entre seeds y el decorator de `Order` |

Los servicios viven bajo `Geekstack::` (no `Spree::`) porque Zeitwerk choca con el
namespace del gem. `app/services/geekstack/mercado_pago.rb` existe solo para
declarar el módulo — no borrarlo.

## Flujo MercadoPago (Checkout Pro)

1. Front llama `POST /api/v3/store/carts/:cart_id/mercado_pago/preference`
   (sin body, con `x-spree-token`).
2. Backend crea la preferencia en MP, crea un `Spree::Payment` en estado
   `checkout` con `response_code = preference_id`, y devuelve `init_point`.
3. Front redirige a `init_point`. El usuario paga en MP.
4. MP redirige a las back_urls (preferences del payment method; en dev apuntan a
   `localhost:3001`, y `auto_return` se desactiva automáticamente si la URL es
   localhost porque MP lo rechaza en sandbox).
5. El estado real llega por webhook → `WebhookJob` → `ProcessPayment`.
   **Nunca confiar solo en el redirect de vuelta.**

Credenciales actuales: TEST, guardadas como preferences en la BD (tabla
`spree_preferences`). Antes de producción moverlas a `Rails.credentials`/ENV y
rotarlas.

Detalles de robustez (agregados tras testear el flujo, ver tests en
`test/services/geekstack/mercado_pago/` y `test/controllers/.../mercado_pago_controller_test.rb`):

- El webhook **no** requiere `X-Spree-Api-Key` (MercadoPago no lo envía;
  `skip_before_action :authenticate_api_key!, only: :webhook`). En su lugar
  valida la firma HMAC-SHA256 (`x-signature` + `x-request-id`) contra
  `preferred_webhook_secret` del payment method. Si el secret no está
  configurado, deja pasar el webhook igual (con warning en log) — hay que
  setear el secret real antes de producción.
- `find_by_prefix_id!`/`response_code` **no** sirve para matchear el pago en
  `ProcessPayment`: el recurso Payment de MercadoPago no trae `preference_id`.
  Se matchea por `order` (via `external_reference`) + el pago más reciente en
  estado `checkout`/`pending` de ese payment method.
- El state machine de `Spree::Payment` en esta versión usa predicados
  `can_<evento>?`, **no** `may_<evento>?` (ese era el nombre en la gema
  `state_machine` clásica; acá es `state_machines`). Mismo para `Spree::Order`
  (`can_next?`).
- Un pago rechazado/cancelado en MP nunca pasó por `pending`/`processing` en
  Spree (sigue en `checkout`), así que la transición válida es `void!`, no
  `failure!` (esa solo acepta `pending`/`processing` como origen).
- Cada llamada a `/preference` voidea los pagos `checkout` previos del mismo
  payment method en esa orden, para no acumular duplicados si el usuario
  reintenta el pago.
- Cada respuesta de `/v1/payments/:id` se guarda como `Spree::LogEntry` en el
  payment (`payment.log_entries.create!(details: mp_payment.to_json)`) para
  auditoría — se ve en el admin de Spree en el detalle del pago.

## Gotchas de la API v3 (aprendidos a golpes)

- Respuestas **planas**, no JSON:API: `response.name`, no `response.data.attributes.name`.
- IDs con prefijo: `cart_xxx`, `variant_xxx`, `ful_xxx`, `dr_xxx`. En controllers
  custom usar `Spree::Order.find_by_prefix_id!(params[:cart_id])`.
- Headers: `X-Spree-Api-Key` (publishable key) siempre; `x-spree-token`
  (en minúsculas) para el carrito; `Authorization: Bearer <jwt>` para el usuario.
- Rutas de cuenta (v3, distintas de v2): `POST /customers` (registro),
  `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`,
  `GET|PATCH /customers/me`, `GET /customers/me/orders`.
- `POST /customers` recibe `email`, `password`, `password_confirmation`
  **en el root del body, sin wrapper** `{ user: ... }`.
- Direcciones: `shipping_address` con `first_name`/`last_name`/`postal_code`
  (no `firstname`/`zipcode`). El carrito responde `fulfillments[].delivery_rates`
  (no `shipments[].shipping_rates`).
- Cart endpoints en plural: `/api/v3/store/carts`.
- Ransack en query params: `?q[taxons_id_eq]=<id>` (usar `curl -g`).
- Traducciones (nombre/label de option types, taxons) son Mobility:
  setear con `Mobility.with_locale(:es) { record.update!(label: "...") }`.
  Evitar tildes en nombres de taxons (stringex revienta con encoding).
- Precios del master variant: `set_price` no persiste; usar
  `variant.prices.find_or_initialize_by(currency: "CLP")` y guardar. Un master
  sin precio CLP produce el 422 engañoso "X is not available in CLP" / `insufficient_stock`.
- `ShippingMethod#display_on` acepta `"both"`, `"front_end"`, `"back_end"`.
- **`Spree::Seeds::States` (el seed nativo de regiones, basado en Carmen) está
  deshabilitado para Chile** vía `app/models/spree/seeds/states_decorator.rb`.
  Carmen para Chile solo tiene 15 regiones **planas, sin comunas** (`Carmen::
  Country.named("Chile").subregions` no tiene `subregions` propias — ni
  siquiera incluye Ñuble, creada en 2018), así que no sirve como fuente de
  comunas. Peor: `Spree::State` es una tabla plana (sin concepto de "región"
  vs "comuna") con `name` único por país, y varias regiones chilenas
  comparten nombre exacto con su comuna capital (Antofagasta, Valparaíso) —
  si esa comuna ya existe (nosotros solo sembramos a nivel comuna) y luego
  corre el seed nativo de regiones, choca por nombre duplicado y `db:seed`
  revienta con `Name has already been taken` en **cualquier corrida
  posterior a la primera** (la primera corrida no falla porque
  `states_required` todavía es `false` en ese momento; el seed nativo solo se
  activa cuando ya está en `true`, lo que persiste desde la corrida
  anterior). El decorator hace que Spree nunca toque Chile a nivel Carmen —
  no perdemos nada real porque Carmen no tenía comunas de todas formas.
- **Las 346 comunas oficiales (16 regiones) están en
  `Geekstack::ChileRegions::REGIONS`** (transcritas a mano desde
  SUBDERE/INE — conviene revisarlas contra una fuente oficial antes de
  confiar en ellas más allá de dev/zonas de despacho), y `db/seeds.rb` las
  siembra todas como `Spree::State`, una por comuna, con `region` seteado al
  nombre de la región — el "padre" que la tabla plana de Spree no modela por
  sí sola. Las zonas de despacho (`STORE_LOCATIONS`) solo referencian un
  subconjunto de esas comunas por nombre (`find_by!`, ya no las crean).

## Gotchas de testing (aprendidos a golpes)

- `Spree::Stores::FindDefault` (lo que resuelve `current_store` en cada
  request) **ignora el host de la request** — solo hace
  `Store.where(default: true).first || Store.first`. Si tu test crea un
  `Spree::Store` sin `default: true`, cualquier otro store que exista en la
  BD (de otro test, o basura vieja) le va a ganar y vas a ver 401 "Valid API
  key required" sin razón aparente. `create_test_store` en
  `test/support/spree_test_helpers.rb` ya fuerza `default: true`.
- `Spree::Store`/`Spree::Product`/etc. usan `paranoia` (soft-delete):
  `destroy`/`destroy_all` no liberan `code`/`slug` únicos. Si necesitas
  limpiar algo a mano fuera de un test (`bin/rails runner`, que no corre en
  una transacción que se revierte solo), usa `.unscoped...delete_all` (hard
  delete) — y ojo que eso tampoco cascadea a tablas relacionadas como
  `friendly_id_slugs`, que puede quedar con filas huérfanas bloqueando el
  slug en el siguiente `create!`.
- Los productos usan Mobility con `column_fallback` (espeja `name` a la
  columna física solo si `I18n.locale == I18n.default_locale`). Si un test de
  integración anterior deja `I18n.locale` en `"es-CL"` sin resetear, el
  siguiente test que cree un `Product` revienta con
  `NotNullViolation: null value in column "name"`. `test_helper.rb` ya trae
  un `teardown { I18n.locale = I18n.default_locale }` global — no lo borres.
- Line items exigen producto `status: "active"` (no `"draft"`) y un
  `Spree::StockItem` con `count_on_hand` > 0 (o `backorderable: true`), si no
  tiras "Draft and archived products cannot be added to cart" o "Quantity
  selected ... is not available". `create_test_product` ya arma ambos.
- `order.line_items.create!` **no** recalcula `order.total`; hay que llamar
  `order.update_with_updater!` después (`add_line_item` ya lo hace).
- El state machine de `Spree::Payment`/`Spree::Order` en esta versión expone
  `can_<evento>?`, no `may_<evento>?` — ver nota en la sección de MercadoPago.

## Convenciones del repo

- Rutas custom de API se agregan en `config/routes.rb` dentro de
  `Spree::Core::Engine.add_routes` bajo `namespace :api > :v3 > :store`.
- Admin en `/admin` (Devise scope separado `Spree::AdminUser`); root redirige ahí.
- Plan de trabajo e íntems pendientes: ver `ROADMAP.md`.
