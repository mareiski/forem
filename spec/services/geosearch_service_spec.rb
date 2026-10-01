require 'rails_helper'

RSpec.describe GeosearchService, type: :service do
  let(:service) { described_class.new }
  let(:user) { create(:user) }
  let(:article1) { create(:article, user: user) }
  let(:article2) { create(:article, user: user) }
  
  # NYC coordinates
  let(:nyc_lon) { -73.9857 }
  let(:nyc_lat) { 40.7484 }
  
  # Jersey City coordinates
  let(:jersey_lon) { -74.0060 }
  let(:jersey_lat) { 40.7128 }
  
  # Boston coordinates
  let(:boston_lon) { -71.0589 }
  let(:boston_lat) { 42.3601 }
  
  before do
    # Create geodata for articles
    @geodatum1 = create(:article_geodatum, 
      article: article1,
      geojson_data: {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [nyc_lon, nyc_lat]
        },
        properties: { name: 'NYC Location' }
      },
      geometry_type: 'Point'
    )
    
    @geodatum2 = create(:article_geodatum,
      article: article2,
      geojson_data: {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [boston_lon, boston_lat]
        },
        properties: { name: 'Boston Location' }
      },
      geometry_type: 'Point'
    )
  end
  
  describe '#search_near_point' do
    it 'finds articles within radius' do
      # Search around NYC with 100km radius should find NYC article
      results = service.search_near_point([nyc_lon, nyc_lat], radius_meters: 100_000)
      
      expect(results.length).to be >= 1
      expect(results.any? { |r| r.article.id == article1.id }).to be true
    end
    
    it 'does not find articles outside radius' do
      # Search around NYC with 10km radius should not find Boston article
      results = service.search_near_point([nyc_lon, nyc_lat], radius_meters: 10_000)
      
      expect(results.any? { |r| r.article.id == article2.id }).to be false
    end
    
    it 'orders results by distance' do
      # Create a third article closer to NYC
      article3 = create(:article, user: user)
      geodatum3 = create(:article_geodatum,
        article: article3,
        geojson_data: {
          type: 'Feature',
          geometry: {
            type: 'Point',
            coordinates: [nyc_lon + 0.01, nyc_lat + 0.01] # Very close to NYC
          },
          properties: { name: 'Very Close Location' }
        },
        geometry_type: 'Point'
      )
      
      results = service.search_near_point([nyc_lon, nyc_lat], radius_meters: 100_000)
      
      # The article3 should be first (closest)
      expect(results.length).to be >= 2
      expect(results.first.article.id).to eq(article3.id)
    end
  end
  
  describe '#search_within_bounds' do
    it 'finds articles within bounding box' do
      # Bounding box around NYC
      bounds = {
        min_lon: -74.2,
        min_lat: 40.5,
        max_lon: -73.8,
        max_lat: 41.0
      }
      
      results = service.search_within_bounds(bounds)
      
      expect(results.any? { |a| a.id == article1.id }).to be true
      expect(results.any? { |a| a.id == article2.id }).to be false
    end
  end
  
  describe '#find_nearest' do
    it 'finds the nearest articles' do
      results = service.find_nearest([nyc_lon, nyc_lat], limit: 1)
      
      expect(results.length).to eq(1)
      expect(results.first.article.id).to eq(article1.id)
    end
  end
  
  describe '#count_within_radius' do
    it 'counts articles within radius' do
      count = service.count_within_radius([nyc_lon, nyc_lat], radius_km: 100)
      
      expect(count).to be >= 1
    end
  end
  
  describe '#articles_with_geodata' do
    it 'returns articles with geodata' do
      articles = service.articles_with_geodata
      
      expect(articles.length).to be >= 2
      expect(articles.map(&:id)).to include(article1.id, article2.id)
    end
  end
end
