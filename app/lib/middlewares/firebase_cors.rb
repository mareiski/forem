module Middlewares
  class FirebaseCors
    PATHS = ["/api/auth/firebase_exchange", "/api/v0/auth/firebase_exchange"].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless PATHS.include?(env["PATH_INFO"])

      origin = env["HTTP_ORIGIN"]
      return @app.call(env) unless allowed_origin?(origin)

      if env["REQUEST_METHOD"] == "OPTIONS"
        return [204, cors_headers(origin), []]
      end

      status, headers, body = @app.call(env)
      headers["Set-Cookie"] = cross_site_session_cookie(headers["Set-Cookie"])
      [status, headers.merge(cors_headers(origin)), body]
    end

    private

    def allowed_origin?(origin)
      origin.present? && configured_origins.include?(origin)
    end

    def configured_origins
      ApplicationConfig["FIREBASE_AUTH_ORIGIN"].to_s.split(",").map(&:strip)
    end

    def cross_site_session_cookie(set_cookie_header)
      return set_cookie_header if set_cookie_header.blank?

      cookies = set_cookie_header.is_a?(Array) ? set_cookie_header : set_cookie_header.split("\n")

      cookies.map do |cookie|
        next cookie unless session_cookie?(cookie)

        cookie = if cookie.match?(/;\s*samesite=[^;]*/i)
                   cookie.sub(/;\s*samesite=[^;]*/i, "; SameSite=None")
                 else
                   "#{cookie}; SameSite=None"
                 end

        cookie.match?(/(?:^|;)\s*secure(?:;|$)/i) ? cookie : "#{cookie}; Secure"
      end.then { |cookies| set_cookie_header.is_a?(Array) ? cookies : cookies.join("\n") }
    end

    def session_cookie?(cookie)
      session_cookie_names.any? { |name| cookie.start_with?("#{name}=") }
    end

    def session_cookie_names
      [
        ApplicationConfig["SESSION_KEY"],
        Rails.application.config.session_options[:key],
        "_session_id",
      ].map(&:presence).compact.uniq
    end

    def cors_headers(origin)
      {
        "Access-Control-Allow-Origin" => origin,
        "Access-Control-Allow-Credentials" => "true",
        "Access-Control-Allow-Methods" => "POST, OPTIONS",
        "Access-Control-Allow-Headers" => "Authorization, Content-Type",
        "Vary" => "Origin",
      }
    end
  end
end
