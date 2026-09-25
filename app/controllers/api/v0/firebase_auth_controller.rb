module Api
  module V0
    class FirebaseAuthController < Api::V0::ApiController
      include Devise::Controllers::Helpers

      skip_before_action :verify_authenticity_token, only: %i[create options]
      before_action :set_cors_headers
      before_action :reject_disallowed_origin

      def options
        set_cors_headers
        render json: {}, status: :ok
      end

      def create
        token = request.headers["Authorization"].to_s.delete_prefix("Bearer ").presence || params[:token]
        claims = ::Authentication::FirebaseTokenVerifier.call(token)
        auth_payload = firebase_auth_payload(claims)
        user = ::Authentication::Authenticator.call(auth_payload, current_user: current_user)

        return render json: { error: "Authentication failed" }, status: :unauthorized unless user.persisted? && user.valid?
        return render json: { error: "Authentication failed" }, status: :unauthorized if user.spam_or_suspended?

        user.confirm if claims["email_verified"] == true && !user.confirmed?
        user.update_tracked_fields!(request)
        configure_cross_origin_session if request.origin.present? && request.origin != request.base_url
        bypass_sign_in(user)

        return redirect_to safe_return_to, allow_other_host: false if params[:return_to].present?

        render json: {
          user: { id: user.id, email: user.email },
          csrf_token: form_authenticity_token,
        }, status: :ok
      rescue ::Authentication::FirebaseTokenVerifier::InvalidToken
        render json: { error: "Invalid Firebase token" }, status: :unauthorized
      rescue ::Authentication::Errors::ProviderNotEnabled, ::Authentication::Errors::ProviderNotFound
        render json: { error: "Firebase authentication is not enabled" }, status: :service_unavailable
      end

      private

      def configure_cross_origin_session
        request.session_options[:same_site] = :none
        request.session_options[:secure] = true
      end

      def safe_return_to
        return_to = params[:return_to].to_s
        uri = Addressable::URI.parse(return_to)

        if uri.host.blank? || uri.host == request.host
          uri.to_s
        else
          root_path
        end
      rescue Addressable::URI::InvalidURIError
        root_path
      end

      def firebase_auth_payload(claims)
        OmniAuth::AuthHash.new(
          provider: "firebase",
          uid: claims.fetch("sub"),
          info: {
            email: claims.fetch("email"),
            name: claims["name"],
            image: claims["picture"],
            nickname: claims["username"],
          },
          credentials: { token: nil, secret: nil },
          extra: { raw_info: claims.except("firebase") },
        )
      end

      def set_cors_headers
        origin = request.headers["Origin"]
        return unless allowed_origin?(origin)

        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
        response.headers["Vary"] = "Origin"
      end

      def reject_disallowed_origin
        origin = request.headers["Origin"]
        return if origin.blank? || allowed_origin?(origin)

        render json: { error: "Origin not allowed" }, status: :forbidden
      end

      def allowed_origin?(origin)
        origin.present? && ApplicationConfig["FIREBASE_AUTH_ORIGIN"].to_s.split(",").map(&:strip).include?(origin)
      end
    end
  end
end
