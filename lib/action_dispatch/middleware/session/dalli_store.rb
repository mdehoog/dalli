require 'active_support/cache'
require 'action_dispatch/middleware/session/abstract_store'
require 'dalli'

# Dalli-based session store for Rails 3.0. Use like so:
#
# require 'action_dispatch/middleware/session/dalli_store'
# config.session_store ActionDispatch::Session::DalliStore, ['cache-1', 'cache-2'], :expire_after => 2.weeks
module ActionDispatch
  module Session
    class DalliStore < AbstractStore
      def initialize(app, options = {})
        # Support old :expires option
        options[:expire_after] ||= options[:expires]

        super

        @default_options = {
          :namespace => 'rack:session',
          :memcache_server => 'localhost:11211',
          :expires_in => options[:expire_after]
        }.merge(@default_options)

        @pool = options[:cache] || begin
          Dalli::Client.new( 
              @default_options[:memcache_server], @default_options)
        end
        @namespace = @default_options[:namespace]

        super
      end

      private
      
        def session_key(sid)
          # Dalli does not support namespaces directly so we have
          # to roll our own.
          @namespace ? "#{@namespace}:#{sid}" : sid
        end

        def get_session(env, sid)
          begin
            session = @pool.get(session_key(sid)) || {}
          rescue Dalli::DalliError => de
            Rails.logger.warn("Session::DalliStore: #{$!.message}")
            session = {}
          end
          [sid, session]
        end

        def set_session(env, sid, session_data)
          options = env['rack.session.options']
          expiry  = options[:expire_after] || 0
          @pool.set(session_key(sid), session_data, expiry)
          sid
        rescue Dalli::DalliError
          Rails.logger.warn("Session::DalliStore: #{$!.message}")
          false
        end

        def destroy(env)
          if sid = current_session_id(env)
            @pool.delete(session_key(sid))
          end
        rescue Dalli::DalliError
          Rails.logger.warn("Session::DalliStore: #{$!.message}")
          false
        end

    end
  end
end
