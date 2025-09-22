# frozen_string_literal: true

# Development configuration for SecureExternalId
if Rails.env.development? || Rails.env.test?
  # Generate a consistent 32-byte key for development/test
  DEVELOPMENT_KEY = "development_key_32_bytes_long!!!"

  # Mock GlobalConfig.dig to return the development configuration
  class GlobalConfig
    class << self
      alias_method :original_dig, :dig

      def dig(*parts, default: :__no_default_provided__)
        if parts == [:secure_external_id] && (Rails.env.development? || Rails.env.test?)
          {
            primary_key_version: "1",
            keys: { "1" => DEVELOPMENT_KEY }
          }
        else
          original_dig(*parts, default: default)
        end
      end
    end
  end
end
