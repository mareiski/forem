# Be sure to restart your server when you modify this file.

require "ipaddr"

module LocalSessionCookieDomain
  private

  def set_cookie(env, session_id, cookie)
    host = env["HTTP_HOST"].to_s.split(":").first
    cookie.delete(:domain) if host.blank? || host == "localhost" || local_ip?(host)
    super
  end

  def local_ip?(host)
    IPAddr.new(host).to_s == host
  rescue IPAddr::InvalidAddressError
    false
  end
end

ActionDispatch::Session::RedisStore.prepend(LocalSessionCookieDomain)

# we want a default in case the expiration is not set or set to 0
# because 0 is an invalid value
app_config_expires_after = ApplicationConfig["SESSION_EXPIRY_SECONDS"].to_i
expires_after = app_config_expires_after.positive? ? app_config_expires_after : 2.weeks.to_i

# See https://github.com/redis-store/redis-rails#session-storage for configuration options
servers = ApplicationConfig["REDIS_SESSIONS_URL"] || ApplicationConfig["REDIS_URL"]
if Rails.env.development?
  begin
    require "uri"
    uri = URI.parse(servers)
    uri.path = "/1" if uri.path.nil? || uri.path == "" || uri.path == "/"
    servers = uri.to_s
  rescue URI::InvalidURIError
  end
end

domain = nil
if Rails.env.production?
  configured_domain = ApplicationConfig["APP_DOMAIN"].to_s.split(":").first
  local_host = configured_domain.blank? || configured_domain == "localhost"

  begin
    local_host ||= IPAddr.new(configured_domain).to_s == configured_domain
  rescue IPAddr::InvalidAddressError
    # Hostnames are expected here; only IP addresses need special handling.
  end

  domain = configured_domain unless local_host
end

begin
  parsed = PublicSuffix.parse(domain, default_rule: nil)
  parsed.domain # Returns the domain with TLD, e.g. "example.com"
  domain = parsed.domain
rescue PublicSuffix::DomainInvalid
  domain = nil
end

# Main session store
Rails.application.config.session_store :redis_store,
                                       key: ApplicationConfig["SESSION_KEY"],
                                       domain: domain,
                                       servers: servers,
                                       expire_after: expires_after,
                                       secure: ApplicationConfig["FORCE_SSL_IN_RAILS"] == "true",
                                       same_site: :lax,
                                       httponly: true

# iFrame session store options
Rails.application.config.iframe_session_options = {
  key: "_iframe_session",
  domain: domain,
  servers: servers,
  expire_after: 48.hours.to_i, # Shorter expiration time for the iFrame session
  secure: ApplicationConfig["FORCE_SSL_IN_RAILS"] == "true",
  same_site: :none,
  httponly: true,
  path: "/auth_pass" # Limit the cookie to the /auth_pass path
}
