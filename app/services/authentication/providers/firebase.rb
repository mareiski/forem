module Authentication
  module Providers
    class Firebase < Provider
      OFFICIAL_NAME = "Firebase".freeze

      def self.official_name
        OFFICIAL_NAME
      end

      def self.settings_url
        "https://console.firebase.google.com/"
      end

      def self.sign_in_path(**_kwargs)
        ApplicationConfig["FIREBASE_AUTH_ORIGIN"]
      end

      def self.user_username_field
        :firebase_username
      end

      def new_user_data
        {
          name: info.name.presence || info.email.split("@").first,
          email: info.email,
          firebase_username: user_nickname
        }
      end

      def existing_user_data
        { firebase_username: user_nickname }
      end

      def user_nickname
        "firebase_#{Digest::SHA256.hexdigest(auth_payload.uid.to_s)[0, 20]}"
      end

      protected

      def cleanup_payload(auth_payload)
        auth_payload
      end
    end
  end
end
