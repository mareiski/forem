module Middlewares
  # Since we must explicitly set the cookie domain in session_store before Settings::General is available,
  # this ensures we properly set the cookie to Settings::General.app_domain at runtime.
  class SetCookieDomain
    require "ipaddr"

    def initialize(app)
      @app = app
    end

    def call(env)
      host = env["HTTP_HOST"].to_s.split(":").first
      env["rack.session.options"][:domain] = cookie_domain(host)
      env["rack.session.options"][:secure] = https_request?(env)

      @app.call(env)
    end

    def https_request?(env)
      env["HTTP_X_FORWARDED_PROTO"].to_s.split(",").first.strip == "https" ||
        env["rack.url_scheme"] == "https"
    end

    def cookie_domain(host)
      return nil if host.blank? || host == "localhost" || local_ip?(host)

      ".#{root_domain(host)}"
    end

    def local_ip?(host)
      IPAddr.new(host).to_s == host
    rescue IPAddr::InvalidAddressError
      false
    end

    def root_domain(host)
      # The `default_rule: nil` option ensures it raises an error if the domain is invalid
      parsed = PublicSuffix.parse(host, default_rule: nil)
      parsed.domain  # Returns the domain with TLD, e.g. "example.com"
    rescue PublicSuffix::DomainInvalid
      host
    end
  end
end
