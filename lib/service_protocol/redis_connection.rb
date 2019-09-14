# frozen_string_literal: true

module ServiceProtocol
  # Redis Connection and Queue
  module RedisConnection
    def redis
      @redis ||= begin
        require 'redis'
        Redis.new(
          url: ENV['REDIS_URL'] || 'redis://redis/0' # , logger: Logger.new(STDOUT)
        )
      end
    end

    def redis_queue
      @redis_queue ||= begin
        require 'redis-queue'
        Redis::Queue.new(queue_name, "#{queue_name}:processing", redis: redis)
      end
    end

    def redis_error(error)
      redis.lpush "#{queue_name}:errors", JSON.dump(
        request: raw_request,
        error: error.inspect
      )
    end
  end
end
