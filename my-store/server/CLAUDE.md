# Spree Commerce Backend

This is a Rails application powered by [Spree Commerce](https://spreecommerce.org).

## Spree Documentation

If `@spree/docs` is installed (via the parent project's `package.json`), full developer docs are at:
`../node_modules/@spree/docs/dist/`

Key resources:
- `dist/developer/core-concepts/` — Products, orders, payments, inventory, etc.
- `dist/developer/customization/` — Decorators, extensions, configuration, dependencies
- `dist/api-reference/store.yaml` — OpenAPI 3.0 spec with all Store API endpoints, parameters, and response schemas. Read this when working on API integrations or building against the Store API.

Otherwise, refer to:
- https://spreecommerce.org/docs/llms.txt - links to all documentation pages in markdown
- https://spreecommerce.org/docs/api-reference/store.yaml - Store API OpenAPI 3.0 spec

## Architecture

- Rails app with Spree engines mounted at `/`
- React admin dashboard at `/dashboard` (served by `spree_dashboard`; authenticates via the Admin API)
- Store API v3 at `/api/v3/store/`
- Admin API v3 at `/api/v3/admin/`
- Background jobs via Solid Queue (in Postgres, runs inside Puma by default) — dashboard at `/jobs`
- Product search runs on the database by default; the optional Meilisearch provider (`spree_meilisearch`) activates when `MEILISEARCH_URL` is set (compose service ships commented out)

## Key Files

| File | Purpose |
|------|---------|
| `config/initializers/spree.rb` | Spree configuration, dependencies, permissions |
| `config/routes.rb` | Route mounting and authentication |
| `Gemfile` | Spree gem versions and extensions |
| `.env` | Environment variables (`SPREE_PATH` for local dev) |

## Customization Patterns

MUST use this in this order — decorators should be a last resort as they couple your code to Spree internals and make upgrades harder.

### 1. Events & Subscribers (preferred for side effects)

React to model changes without touching Spree source. Use for syncing to external services, sending notifications, updating caches, etc.

Generate one with `bin/rails g spree:subscriber OrderPlaced order.placed` — it writes the class, a spec, and registers it.

```ruby
# app/subscribers/order_placed_subscriber.rb
class OrderPlacedSubscriber < Spree::Subscriber
  subscribes_to 'order.placed'

  def handle(event)
    order = Spree::Order.find_by_prefix_id(event.payload['id'])
    return unless order

    ExternalService.notify(order)
  end
end
```

Subscribers are not auto-discovered — register in `config/initializers/spree.rb`:

```ruby
Rails.application.config.after_initialize do
  Spree.subscribers << OrderPlacedSubscriber
end
```

### 2. Workflow Hooks, then Swapping Workflows (Dependencies)

To run your own code inside a Spree flow (validate, react, contribute data), register a hook — hooks survive upgrades:

```ruby
# config/initializers/spree.rb
Spree.hooks.register('carts.add_item.validate', 'MyApp::CheckPurchaseLimit')
```

```ruby
module MyApp
  class CheckPurchaseLimit
    def call(workflow)
      return if workflow.quantity <= 10

      workflow.errors.add(:quantity, :purchase_limit_exceeded, message: 'You can order at most 10 of this item.')
      workflow.reject!
    end
  end
end
```

Only when no hook fits, replace the whole workflow by subclassing it:

```ruby
module MyApp
  module Carts
    class AddItem < Spree::Carts::AddItem
      workflow_key 'carts.add_item' # keep hooks registered on the original key firing

      def perform(variant:, cart: nil, **rest)
        super
        # your logic
      end
    end
  end
end
```

Register in `config/initializers/spree.rb`:

```ruby
Spree.dependencies do |dependencies|
  dependencies.cart_add_item_workflow = 'MyApp::Carts::AddItem'
end
```

### 3. Adding Extensions

Add to `Gemfile`

```ruby
gem 'spree_stripe'
```

Run `bundle install`

Run the extension installer, e.g. `bin/rails g spree_stripe:install`
Convention is `bin/rails g <extension_name>:install`

### 4. Decorators (last resort)

Only use for structural changes (adding associations, validations, scopes). Avoid for callbacks and side effects — use subscribers instead.

```ruby
# app/models/spree/product_decorator.rb
module Spree
  module ProductDecorator
    def self.prepended(base)
      base.has_many :reviews, class_name: 'MyApp::Review', dependent: :destroy
      base.validates :custom_field, presence: true
    end
  end

  Product.prepend ProductDecorator
end
```

## Development

```bash
bin/setup              # Install dependencies, prepare database, index search
bin/dev                # Start web (jobs run in-process)
bin/rails console      # Rails console
bin/rails db:migrate   # Run migrations
bin/rails db:seed      # Seed the databases
```

## Coding Conventions

- All custom code goes in `app/` — never modify gem source
- Use decorators in `app/models/spree/` for model extensions
- Use `Spree.customer_class` / `Spree.admin_user_class` — never reference `Spree::Customer` directly
- All Spree models are namespaced under `Spree::` (e.g., `Spree::Product`, `Spree::Order`)
- Use `Spree::Current.store`, `Spree::Current.currency`, `Spree::Current.locale` for request context
- Prefixed IDs in API (e.g., `prod_86Rf07xd4z`) — never expose raw database IDs
- Events system for side effects: `order.publish_event('order.placed')`
- CanCanCan for authorization, Ransack for filtering, Pagy for pagination

## Testing

Native (host Ruby):

```bash
bundle exec rspec                           # Full test suite
bundle exec rspec spec/models/              # Model specs only
bundle exec rspec spec/models/my_model.rb   # Single file
```

Docker (via `@spree/cli`): `spree rspec …` runs the same commands inside the web container with `RAILS_ENV=test`, against the `spree_test` database. First run: `spree rails db:test:prepare`.
