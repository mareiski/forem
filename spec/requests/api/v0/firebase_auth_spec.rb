require "rails_helper"

RSpec.describe "Api::V0::FirebaseAuth", type: :request do
  let(:origin) { "https://roundtrips.example" }
  let(:headers) do
    {
      "Origin" => origin,
      "Authorization" => "Bearer firebase-token",
    }
  end
  let(:claims) do
    {
      "sub" => "firebase-user-1",
      "email" => "firebase@example.com",
      "email_verified" => true,
      "name" => "Firebase User",
      "picture" => "https://example.com/profile.jpg",
    }
  end

  before do
    allow(ApplicationConfig).to receive(:[]).and_call_original
    allow(ApplicationConfig).to receive(:[]).with("FIREBASE_AUTH_ORIGIN").and_return(origin)
    allow(Settings::Authentication).to receive(:firebase_project_id).and_return("roundtrips4you-2")
    allow(Settings::Authentication).to receive(:providers).and_return([:firebase])
    allow(Authentication::FirebaseTokenVerifier).to receive(:call).and_return(claims)
  end

  it "creates a Forem user, identity, and session" do
    expect do
      post "/api/v0/auth/firebase_exchange", headers: headers
    end.to change(User, :count).by(1).and change(Identity, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(origin)
    expect(response.cookies).to include("remember_user_token")

    identity = Identity.find_by!(provider: "firebase", uid: "firebase-user-1")
    expect(identity.user.email).to eq("firebase@example.com")
  end

  it "does not create duplicates when exchanging the same token twice" do
    2.times { post "/api/v0/auth/firebase_exchange", headers: headers }

    expect(User.where(email: "firebase@example.com").count).to eq(1)
    expect(Identity.where(provider: "firebase", uid: "firebase-user-1").count).to eq(1)
  end

  it "rejects an invalid token" do
    allow(Authentication::FirebaseTokenVerifier).to receive(:call).and_raise(
      Authentication::FirebaseTokenVerifier::InvalidToken,
    )

    post "/api/v0/auth/firebase_exchange", headers: headers

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["error"]).to eq("Invalid Firebase token")
  end

  it "rejects an untrusted origin" do
    post "/api/v0/auth/firebase_exchange", headers: headers.merge("Origin" => "https://attacker.example")

    expect(response).to have_http_status(:forbidden)
    expect(User.count).to eq(0)
  end
end