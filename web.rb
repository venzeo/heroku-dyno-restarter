require 'sinatra'
require 'redis'
require 'platform-api'

REDIS  = Redis.new(url: ENV['REDIS_URL'] || ENV["REDISCLOUD_URL"])
HEROKU = PlatformAPI.connect(ENV['HEROKU_API_KEY'])
RESTART_INTERVAL = (ENV['RESTART_INTERVAL'] || 1800).to_i

get '/' do
  status 404
end

get '/webhook' do
  return bad_request('invalid api token') unless params[:token] == ENV['APP_API_TOKEN']
 
  source_name = ENV['SOURCE_APP_NAME']
  restart_key = "heroku-dyno-restarter:restarts:#{source_name}:all"

  logger.info "Check in REDIS whether we restarted anything in past X seconds"
  if REDIS.get(restart_key)
    logger.info "[skip] restart_key exists: #{restart_key} for #{REDIS.ttl(restart_key)}"
    return bad_request('already restarted')
  end

  logger.info "Saving to REDIS"
  REDIS.setex(restart_key, RESTART_INTERVAL, 1)
  logger.info "[RESTARTING] #{source_name}:all"
  HEROKU.dyno.restart_all(source_name)

  logger.info "done restarting."

  status 200
  'ok'
end

def bad_request(body)
  status 400
  body
end
