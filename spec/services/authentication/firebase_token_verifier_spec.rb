require "rails_helper"

RSpec.describe Authentication::FirebaseTokenVerifier do
  let(:project_id) { "roundtrips4you-2" }
  let(:claims) do
    {
      "sub" => "firebase-user-1",
      "email" => "user@example.com",
      "email_verified" => true,
      "iss" => "https://securetoken.google.com/#{project_id}",
      "aud" => project_id,
    }
  end

  before do
    allow(Settings::Authentication).to receive(:firebase_project_id).and_return(project_id)
    allow(Google::Auth::IDTokens::Verifier).to receive(:new).and_return(verifier)
    allow(verifier).to receive(:verify).and_return(claims)
  end

  let(:verifier) { instance_double(Google::Auth::IDTokens::Verifier) }

  it "returns verified Firebase claims" do
    expect(described_class.call("firebase-token")).to eq(claims)
    expect(verifier).to have_received(:verify).with(
      "firebase-token",
      aud: project_id,
      iss: "https://securetoken.google.com/#{project_id}",
    )
  end

  it "rejects a token without a verified email" do
    allow(verifier).to receive(:verify).and_return(claims.merge("email_verified" => false))

    expect { described_class.call("firebase-token") }.to raise_error(described_class::InvalidToken)
  end

  it "rejects a token without a configured project" do
    allow(Settings::Authentication).to receive(:firebase_project_id).and_return(nil)

    expect { described_class.call("firebase-token") }.to raise_error(described_class::InvalidToken)
  end
end