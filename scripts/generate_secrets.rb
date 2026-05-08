#!/usr/bin/env ruby
# Production Secrets Generator
# ใช้สำหรับ generate secrets สำหรับ production environment

require 'securerandom'

def generate_secret(length = 64)
  SecureRandom.hex(length / 2)
end

def generate_jwt_secret
  SecureRandom.base64(32)
end

def generate_database_url(config = {})
  host = config[:host] || ENV['DB_HOST'] || 'localhost'
  port = config[:port] || ENV['DB_PORT'] || '5432'
  database = config[:database] || ENV['DB_NAME'] || 'spree_production'
  username = config[:username] || ENV['DB_USERNAME'] || 'spree_user'
  password = config[:password] || ENV['DB_PASSWORD'] || generate_secret(24)
  
  "postgresql://#{username}:#{password}@#{host}:#{port}/#{database}"
end

def generate_env_file
  puts "🔧 Generating Production Secrets..."
  
  secrets = {
    'SECRET_KEY_BASE' => generate_secret(64),
    'RAILS_MASTER_KEY' => generate_secret(32),
    'NEXTAUTH_SECRET' => generate_jwt_secret,
    'DATABASE_URL' => generate_database_url,
    'REDIS_URL' => "redis://localhost:6379/0"
  }
  
  # Generate timestamp
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  
  # Create backup of existing .env.production if it exists
  if File.exist?('.env.production')
    backup_name = ".env.production.backup.#{timestamp}"
    File.rename('.env.production', backup_name)
    puts "✅ Backed up existing .env.production to #{backup_name}"
  end
  
  # Write new .env.production file
  File.open('.env.production', 'w') do |file|
    file.puts "# Production Environment Variables"
    file.puts "# Generated on: #{Time.now}"
    file.puts "# ⚠️ แก้ไขค่าที่จำเป็นจริงสำหรับ production"
    file.puts ""
    
    secrets.each do |key, value|
      if key == 'DATABASE_URL'
        file.puts "# Database Configuration"
        file.puts "DATABASE_URL=#{value}"
        file.puts ""
      elsif key == 'REDIS_URL'
        file.puts "# Redis Configuration"
        file.puts "REDIS_URL=#{value}"
        file.puts ""
      elsif key == 'SECRET_KEY_BASE'
        file.puts "# Rails Secret Key"
        file.puts "SECRET_KEY_BASE=#{value}"
        file.puts ""
      elsif key == 'RAILS_MASTER_KEY'
        file.puts "# Rails Master Key"
        file.puts "RAILS_MASTER_KEY=#{value}"
        file.puts ""
      elsif key == 'NEXTAUTH_SECRET'
        file.puts "# Next.js Auth Secret"
        file.puts "# This should be copied to storefront .env.production"
        file.puts "NEXTAUTH_SECRET=#{value}"
        file.puts ""
      end
    end
    
    file.puts "# Entra ID Configuration (แก้ไขด้วยค่าจริง)"
    file.puts "ENTRA_TENANT_ID=your_production_entra_tenant_id"
    file.puts "ENTRA_CLIENT_ID=your_production_entra_client_id"
    file.puts "ENTRA_CLIENT_SECRET=your_production_entra_client_secret"
    file.puts ""
    
    file.puts "# Spree API Configuration"
    file.puts "SPREE_PUBLISHABLE_KEY=your_production_publishable_key_here"
    file.puts ""
    
    file.puts "# AI Configuration"
    file.puts "GEMINI_API_KEY=your_production_gemini_api_key"
    file.puts ""
    
    file.puts "# Logging"
    file.puts "RAILS_LOG_LEVEL=info"
    file.puts ""
    
    file.puts "# Security"
    file.puts "RAILS_DEVELOPMENT_HOSTS=your_domain.com,www.your_domain.com"
    file.puts ""
    
    file.puts "# Performance"
    file.puts "RAILS_MAX_THREADS=5"
    file.puts "WEB_CONCURRENCY=2"
  end
  
  puts "✅ Generated .env.production file"
  puts "📝 แก้ไขค่าต่อไปนี้:"
  puts "   - ENTRA_TENANT_ID"
  puts "   - ENTRA_CLIENT_ID" 
  puts "   - ENTRA_CLIENT_SECRET"
  puts "   - SPREE_PUBLISHABLE_KEY"
  puts "   - GEMINI_API_KEY"
  puts "   - DATABASE_URL (ถ้าใช้ database ภายนอก)"
  puts ""
  puts "🔐 Generated secrets:"
  puts "   SECRET_KEY_BASE: #{secrets['SECRET_KEY_BASE'][0..20]}..."
  puts "   RAILS_MASTER_KEY: #{secrets['RAILS_MASTER_KEY']}"
  puts "   NEXTAUTH_SECRET: #{secrets['NEXTAUTH_SECRET']}"
  
  # Generate storefront secrets file
  File.open('../spree-storefront/.env.production', 'w') do |file|
    file.puts "# Storefront Production Environment Variables"
    file.puts "# Generated on: #{Time.now}"
    file.puts "# ⚠️ แก้ไขค่าที่จำเป็นจริงสำหรับ production"
    file.puts ""
    
    file.puts "# Spree API Configuration"
    file.puts "SPREE_API_URL=https://your-spree-backend.com"
    file.puts "SPREE_PUBLISHABLE_KEY=your_production_publishable_key_here"
    file.puts ""
    
    file.puts "# Microsoft Entra ID Configuration"
    file.puts "ENTRA_TENANT_ID=your_production_entra_tenant_id"
    file.puts "ENTRA_CLIENT_ID=your_production_entra_client_id"
    file.puts "ENTRA_CLIENT_SECRET=your_production_entra_client_secret"
    file.puts ""
    
    file.puts "# Public Entra ID Configuration (client-side)"
    file.puts "NEXT_PUBLIC_ENTRA_TENANT_ID=your_production_entra_tenant_id"
    file.puts "NEXT_PUBLIC_ENTRA_CLIENT_ID=your_production_entra_client_id"
    file.puts ""
    
    file.puts "# Next.js Configuration"
    file.puts "NEXTAUTH_URL=https://your-storefront-domain.com"
    file.puts "NEXTAUTH_SECRET=#{secrets['NEXTAUTH_SECRET']}"
    file.puts ""
    
    file.puts "# Site Configuration"
    file.puts "NEXT_PUBLIC_SITE_URL=https://your-storefront-domain.com"
    file.puts "NEXT_PUBLIC_DEFAULT_COUNTRY=us"
    file.puts "NEXT_PUBLIC_DEFAULT_LOCALE=en"
    file.puts ""
    
    file.puts "# Security Configuration"
    file.puts "NEXTAUTH_URL_INTERNAL=https://your-storefront-domain.com"
    file.puts "NEXTAUTH_TRUST_HOST=true"
    file.puts ""
    
    file.puts "# Feature Flags"
    file.puts "ENABLE_SSO=true"
    file.puts "ENABLE_ANALYTICS=true"
    file.puts "ENABLE_ERROR_REPORTING=true"
  end
  
  puts "✅ Generated storefront .env.production file"
  puts "🎯 Environment files ready for production setup!"
end

# Run the generator
if __FILE__ == $0
  generate_env_file
end
