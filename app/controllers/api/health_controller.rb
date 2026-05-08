class Api::HealthController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def show
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      uptime: Rails.application.config.booted_at ? Time.current - Rails.application.config.booted_at : 0,
      environment: Rails.env,
      version: Rails.application.config.rails_version,
      spree_version: Spree.version,
      services: {
        database: check_database,
        redis: check_redis
      }
    }
  end
  
  private
  
  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'connected', adapter: ActiveRecord::Base.connection.adapter_name }
  rescue => e
    { status: 'error', message: e.message }
  end
  
  def check_redis
    if defined?(Redis)
      redis = Redis.new(url: ENV['REDIS_URL'])
      redis.ping
      { status: 'connected' }
    else
      { status: 'not_configured' }
    end
  rescue => e
    { status: 'error', message: e.message }
  end
end
