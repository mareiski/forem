require "googleauth"

module Authentication
  class FirebaseTokenVerifier
    class InvalidToken < StandardError; end

    def self.call(token)
      new(token).call
    end

    def initialize(token)
      @token = token
    end

    def call
      raise InvalidToken if token.blank? || project_id.blank?

      claims = verifier.verify(token, aud: project_id, iss: issuer)
      validate_claims!(claims)
      claims
    rescue StandardError => e
      raise InvalidToken, e.message
    end

    private

    attr_reader :token

    def project_id
      Settings::Authentication.firebase_project_id
    end

    def issuer
      "https://securetoken.google.com/#{project_id}"
    end

    def verifier
      @verifier ||= Google::Auth::IDTokens::Verifier.new(
        key_source: Google::Auth::IDTokens::X509CertHttpKeySource.new(
          "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com",
        ),
      )
    end

    def validate_claims!(claims)
      raise InvalidToken unless claims["sub"].present?
      raise InvalidToken unless claims["email"].present? && claims["email_verified"] == true
    end
  end
end