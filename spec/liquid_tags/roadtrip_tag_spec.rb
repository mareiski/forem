require "rails_helper"

RSpec.describe RoadtripTag, type: :liquid_tag do
  let(:user) { create(:user) }
  let(:url) do
    "https://roadtrip-planen.de/reise-ansehen/Roadtrip durch die Region Apulien mit Freunden–Kultur & Natur erleben-1J69eGQkGacMvE1qGQr5IdqQnvbM"
  end

  def generate_tag(input)
    Liquid::Template.parse("{% roadtrip #{input} %}", source: Article.new, user: user)
  end

  it "renders the linked page in an iframe" do
    result = generate_tag(url).render
    iframe = Nokogiri::HTML.fragment(result).at_css(".ltag-roadtrip iframe")

    expect(iframe["src"]).to eq(url)
    expect(iframe["title"]).to eq("Roadtrip Planen")
    expect(iframe["loading"]).to eq("lazy")
  end

  it "routes roadtrip-planen.de URLs through the unified embed registry" do
    expect(UnifiedEmbed::Registry.find_liquid_tag_for(link: url)).to eq(described_class)
  end

  it "rejects URLs from other hosts" do
    expect do
      generate_tag("https://example.com/reise-ansehen/example")
    end.to raise_error(StandardError, /Invalid Roadtrip URL/)
  end

  it "rejects non-HTTPS URLs" do
    expect do
      generate_tag(url.sub("https://", "http://"))
    end.to raise_error(StandardError, /Invalid Roadtrip URL/)
  end
end