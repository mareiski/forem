# Changing the value for "domain" in each context instead of using the one set on boot.
# This allows changing domain settings without restarting app.
require "ipaddr"

module Devise
  module Controllers
    module Rememberable
      # We need to use Settings::General.app_domain instead of default Rails config on boot
      def remember_cookie_values(resource)
        secondary_domains = ApplicationConfig["SECONDARY_APP_DOMAINS"].to_s.split(",").map(&:strip)
        domain = if request && secondary_domains.include?(request.host)
                   request.host
                 else
                   Settings::General.app_domain
                 end
        options = { httponly: true }
        options.merge!(forget_cookie_values(resource))
        options.merge!(
          value: resource.class.serialize_into_cookie(resource),
          expires: resource.remember_expires_at,
        )
        cookie_domain = normalized_cookie_domain(domain)
        options[:domain] = cookie_domain if cookie_domain
        options
      end

      def self.cookie_values
        # Default: Rails.configuration.session_options.slice(:path, :domain, :secure)
        # We need to use Settings::General.app_domain instead of default Rails config on boot
        options = { secure: ApplicationConfig["FORCE_SSL_IN_RAILS"] == "true" }
        cookie_domain = Devise::Controllers::Rememberable.normalized_cookie_domain(Settings::General.app_domain)
        options[:domain] = cookie_domain if cookie_domain
        options
      end

      def self.normalized_cookie_domain(domain)
        host = domain.to_s.split(":").first
        return if host.blank? || host == "localhost" || IPAddr.new(host).to_s == host

        ".#{host}"
      rescue IPAddr::InvalidAddressError
        ".#{host}"
      end

      def normalized_cookie_domain(domain)
        self.class.normalized_cookie_domain(domain)
      end
    end
  end
end
