# frozen_string_literal: true

Premailer::Rails.config[:remove_ids] = false
Premailer::Rails.config[:preserve_style_attribute] = true

if Rails.env.development?
  require "net/http"
  require "openssl"

  module Net
    class HTTP
      alias_method :original_use_ssl=, :use_ssl=

      def use_ssl=(flag)
        self.original_use_ssl = flag
        if flag
          hostname = address
          Rails.logger.debug "[SSL Debug] use_ssl= called for hostname: #{hostname}, port: #{port}"
          if hostname && (hostname == "localhost" || hostname == "127.0.0.1" || hostname.end_with?(".gumroad.dev") || hostname == "gumroad.dev")
            Rails.logger.debug "[SSL Debug] Disabling SSL verification for local domain: #{hostname}"
            self.verify_mode = OpenSSL::SSL::VERIFY_NONE
          else
            Rails.logger.debug "[SSL Debug] Keeping SSL verification enabled for: #{hostname}"
          end
        end
      end

      alias_method :original_connect, :connect

      def connect
        Rails.logger.debug "[SSL Debug] Connecting to #{address}:#{port}"
        original_connect
      rescue OpenSSL::SSL::SSLError => e
        Rails.logger.error "[SSL Debug] SSL Error during connect to #{address}:#{port}: #{e.message}"
        if address && (address == "localhost" || address == "127.0.0.1" || address.end_with?(".gumroad.dev") || address == "gumroad.dev")
          Rails.logger.debug "[SSL Debug] Retrying with SSL verification disabled for local domain"
          self.verify_mode = OpenSSL::SSL::VERIFY_NONE
          original_connect
        else
          raise
        end
      end

      alias_method :original_request, :request

      def request(req, body = nil, &block)
        Rails.logger.debug "[SSL Debug] Making request to #{address}:#{port}#{req.path}"
        original_request(req, body, &block)
      rescue OpenSSL::SSL::SSLError => e
        Rails.logger.error "[SSL Debug] SSL Error for #{address}:#{port}#{req.path}: #{e.message}"
        raise
      end
    end
  end
end
