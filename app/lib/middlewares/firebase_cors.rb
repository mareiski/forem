module Middlewares
  class FirebaseCors
    PATH = "/api/auth/firebase_exchange".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env["PATH_INFO"] == PATH

      origin = env["HTTP_ORIGIN"]
      return @app.call(env) unless allowed_origin?(origin)

      if env["REQUEST_METHOD"] == "OPTIONS"
        return [204, cors_headers(origin), []]
      end

      status, headers, body = @app.call(env)
      [status, headers.merge(cors_headers(origin)), body]
    end

    private

    def allowed_origin?(origin)
      origin.present? && configured_origins.include?(origin)
    end

    def configured_origins
      ApplicationConfig["FIREBASE_AUTH_ORIGIN"].to_s.split(",").map(&:strip)
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