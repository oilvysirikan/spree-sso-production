# Deploy Spree Backend to Production

## 🚀 Deployment Options

### **Option 1: Heroku (Recommended for Quick Setup)**
```bash
# 1. Install Heroku CLI
brew install heroku

# 2. Login to Heroku
heroku login

# 3. Create app
heroku create your-spree-backend

# 4. Set environment variables
heroku config:set RAILS_ENV=production
heroku config:set SECRET_KEY_BASE=$(rails secret)
heroku config:set DATABASE_URL=$(heroku pg:attachment DATABASE_URL)
heroku config:set REDIS_URL=$(heroku addons:create heroku-redis:hobby-dev)

# 5. Add buildpacks
heroku buildpacks:set heroku/ruby
heroku buildpacks:add heroku/nodejs

# 6. Deploy
git push heroku main

# 7. Run migrations
heroku run rails db:migrate
heroku run rails db:seed
```

### **Option 2: DigitalOcean App Platform**
```bash
# 1. Install doctl
brew install doctl

# 2. Create app
doctl apps create --spec spec.yaml

# spec.yaml example:
name: spree-backend
services:
- name: web
  source_dir: /
  github:
    repo: your-username/my_spree_store
    branch: main
  run_command: bundle exec puma -C config/puma.rb
  environment_slug: ruby-on-rails
  instance_count: 1
  instance_size_slug: basic-xxs
  env:
  - key: RAILS_ENV
    value: production
  - key: SECRET_KEY_BASE
    value: your_secret_key
  - key: DATABASE_URL
    value: ${db.DATABASE_URL}
  - key: REDIS_URL
    value: ${redis.REDIS_URL}
databases:
- name: db
  engine: PG
  version: "15"
- name: redis
  engine: REDIS
  version: "7"
```

### **Option 3: AWS Elastic Beanstalk**
```bash
# 1. Install EB CLI
pip install awsebcli

# 2. Initialize
eb init spree-backend --platform "Ruby 3.1 running on 64bit Amazon Linux 2"

# 3. Create environment
eb create production

# 4. Deploy
eb deploy
```

## 📋 Production Checklist

### **Security Configuration**
```ruby
# config/environments/production.rb
Rails.application.configure do
  config.force_ssl = true
  config.log_level = :info
  config.log_tags = [:request_id]
  
  # Asset configuration
  config.assets.compile = false
  config.assets.digest = true
  
  # Cache configuration
  config.cache_store = :redis_cache_store, {
    url: ENV['REDIS_URL'],
    namespace: 'cache'
  }
  
  # Session configuration
  config.session_store :redis_store, {
    servers: [ENV['REDIS_URL']],
    expire_after: 1.hour
  }
end
```

### **Database Configuration**
```ruby
# config/database.yml
production:
  adapter: postgresql
  encoding: unicode
  pool: 5
  url: <%= ENV['DATABASE_URL'] %>
  sslmode: require
```

### **Puma Configuration**
```ruby
# config/puma.rb
environment "production"
threads 4, 8
workers 2
preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || "development"

on_worker_boot do
  ActiveRecord::Base.establish_connection
end

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart
```

### **Sidekiq Configuration**
```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end
```

## 🔍 Health Checks

### **Health Check Endpoint**
```ruby
# config/routes.rb
get '/health', to: 'health#index'

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def index
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: Rails.application.version,
      database: ActiveRecord::Base.connection.active?,
      redis: Redis.new(url: ENV['REDIS_URL']).ping == 'PONG'
    }
  end
end
```

### **Monitoring Setup**
```ruby
# config/initializers/monitoring.rb
if Rails.env.production?
  # Error tracking
  require 'sentry-ruby'
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.traces_sample_rate = 0.1
  end
  
  # Performance monitoring
  require 'newrelic_rpm'
end
```

## 🚀 Deployment Script

### **Automated Deployment Script**
```bash
#!/bin/bash
# deploy.sh

set -e

echo "🚀 Starting deployment..."

# 1. Run tests
echo "📋 Running tests..."
rails test
rails spec

# 2. Precompile assets
echo "🎨 Precompiling assets..."
RAILS_ENV=production rails assets:precompile

# 3. Run migrations
echo "🗄️ Running migrations..."
RAILS_ENV=production rails db:migrate

# 4. Restart services
echo "🔄 Restarting services..."
if command -v heroku &> /dev/null; then
  heroku restart
fi

# 5. Health check
echo "🏥 Running health check..."
sleep 10
curl -f https://your-spree-backend.com/health || exit 1

echo "✅ Deployment completed successfully!"
```

## 🔧 Environment Variables Setup

### **Production .env Setup**
```bash
# 1. Generate secrets
SECRET_KEY_BASE=$(rails secret)
NEXTAUTH_SECRET=$(openssl rand -base64 32)

# 2. Set environment variables
export RAILS_ENV=production
export SECRET_KEY_BASE=$SECRET_KEY_BASE
export DATABASE_URL="postgresql://user:pass@host:5432/db"
export REDIS_URL="redis://host:6379/0"
export ENTRA_TENANT_ID="your-tenant-id"
export ENTRA_CLIENT_ID="your-client-id"
export ENTRA_CLIENT_SECRET="your-client-secret"
export GEMINI_API_KEY="your-gemini-key"
```

## 📊 Performance Optimization

### **Database Optimization**
```sql
-- Add indexes for SSO performance
CREATE INDEX INDEX_social_accounts_on_provider_and_uid ON social_accounts(provider, uid);
CREATE INDEX INDEX_social_accounts_on_spree_user_id ON social_accounts(spree_user_id);

-- Add indexes for user lookup
CREATE INDEX INDEX_spree_users_on_email ON spree_users(email);
```

### **Caching Strategy**
```ruby
# Cache SSO token validation
Rails.cache.fetch("sso_token_#{token_digest}", expires_in: 1.hour) do
  validate_jwt_token(token, provider)
end

# Cache user session data
Rails.cache.fetch("user_session_#{user_id}", expires_in: 30.minutes) do
  spree_token_data
end
```

## 🚨 Error Handling

### **Custom Error Pages**
```ruby
# config/application.rb
config.exceptions_app = self.routes

# config/routes.rb
match '/404', to: 'errors#not_found', via: :all
match '/422', to: 'errors#unprocessable_entity', via: :all
match '/500', to: 'errors#internal_server_error', via: :all
```

### **Error Monitoring**
```ruby
# app/controllers/application_controller.rb
rescue_from StandardError, with: :handle_error

private

def handle_error(exception)
  Rails.logger.error "Error: #{exception.message}"
  Rails.logger.error exception.backtrace.join("\n")
  
  if Rails.env.production?
    Sentry.capture_exception(exception)
    render json: { error: 'Internal server error' }, status: :internal_server_error
  else
    raise exception
  end
end
```
