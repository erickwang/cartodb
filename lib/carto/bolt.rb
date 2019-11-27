module Carto
  class Bolt
    DEFAULT_REDIS_OBJECT = $users_metadata
    DEFAULT_TTL_MS = 10000
    DEFAULT_RETRY_ATTEMPTS = 1
    DEFAULT_RETRY_TIMEOUT = 10000 # in_ms

    def initialize(bolt_key, redis_object: DEFAULT_REDIS_OBJECT, ttl_ms: DEFAULT_TTL_MS)
      @bolt_key = add_namespace_to_key(bolt_key)
      @redis_object = redis_object
      @ttl_ms = ttl_ms
    end

    def run_locked(attempts: DEFAULT_RETRY_ATTEMPTS,
                   timeout: DEFAULT_RETRY_TIMEOUT,
                   rerun_func: nil)
      raise 'no code block given' unless block_given?
      raise 'no proc/lambda passed as rerun_func' if rerun_func.present? && !proc?(rerun_func)

      locked_acquired = acquire_lock(attempts, timeout)

      begin
        if locked_acquired
          remove_retry
          yield
          true
        else
          if rerun_func && !set_retry
            rerun_func.call
          end
          false
        end
      ensure
        unlock if locked_acquired
      end
    end

    private

    def acquire_lock(attempts, timeout)
      attempts.times do |index|
        lock_acquired = get_lock
        # With only 1 attempt, the default value, we dont sleep
        # even if false
        if lock_acquired || (attempts == index + 1)
          return lock_acquired
        end
        sleep((timeout / 1000.0).second)
      end
      CartoDB::Logger.warning(message: "Couldn't acquire bolt after #{attempts} attempts with #{timeout} timeout")
      false
    end

    def proc?(proc)
      proc.respond_to?(:call)
    end

    def unlock
      removed_keys = @redis_object.del(@bolt_key)

      # This may happen due to Redis failure. Highly unlikely, still nice to know.
      if removed_keys > 1
        CartoDB.notify_error('Removed bolt key was duplicated', bolt_key: @bolt_key, amount: removed_keys)
      end

      removed_keys > 0
    end

    def get_lock
      @redis_object.set(@bolt_key, true, px: @ttl_ms, nx: true)
    end

    def remove_retry
      @redis_object.del("#{@bolt_key}:retry")
    end

    def set_retry
      @redis_object.getset("#{@bolt_key}:retry", true)
    end

    def add_namespace_to_key(key)
      "rails:bolt:#{key}"
    end
  end
end
