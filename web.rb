require 'sinatra'
require 'json'
require 'redis'
require 'platform-api'

REDIS  = Redis.new(url: ENV['REDIS_URL'] || ENV["REDISCLOUD_URL"])
HEROKU = PlatformAPI.connect(ENV['HEROKU_API_KEY'])
RESTART_INTERVAL = (ENV['RESTART_INTERVAL'] || 1800).to_i

get '/' do
  status 404
end

get '/webhook' do
  return status 404 unless params[:token] == ENV['APP_API_TOKEN']
  
  events.each do |event|
    
    source_name = ENV['SOURCE_APP_NAME']
    restart_key = "heroku-dyno-restarter:restarts:#{source_name}:all:#{error_code}"
    
    if REDIS.get(restart_key)
      logger.info "[skip] restart_key exists: #{restart_key} for #{REDIS.ttl(restart_key)}"
      next
    end

    REDIS.setex(restart_key, RESTART_INTERVAL, 1)
    logger.info "[RESTARTING] #{source_name}:all by #{error_code}: #{message}"
    HEROKU.dyno.restart_all(source_name)
    
    logger.info "done restarting."
  end

  status 200
  'ok'
end
