require 'rails_helper'

RSpec.describe GeodataService, type: :service do
  let(:user) { create(:user) }
  let(:article) { create(:article, user: user) }
  
  describe 'Firebase endpoint response handling' do
    # Simulate the actual response from the user's endpoint
    let(:firebase_single_point_response) do
      {
        "type" => "FeatureCollection",
        "features" => [
          {
            "type" => "Feature",
            "geometry" => {
              "type" => "Point",
              "coordinates" => [16.871871, 41.117143]
            },
            "properties" => {
              "name" => "Bari"
            }
          }
        ]
      }
    end
    
    let(:firebase_multiple_points_response) do
      {
        "type" => "FeatureCollection",
        "features" => [
          {
            "type" => "Feature",
            "geometry" => {
              "type" => "Point",
              "coordinates" => [16.871871, 41.117143]
            },
            "properties" => {
              "name" => "Bari"
            }
          },
          {
            "type" => "Feature",
            "geometry" => {
              "type": "Point",
              "coordinates" => [16.88, 41.12]
            },
            "properties" => {
              "name" => "Bari Center"
            }
          },
          {
            "type" => "Feature",
            "geometry" => {
              "type": "Point",
              "coordinates" => [16.89, 41.13]
            },
            "properties" => {
              "name" => "Destination"
            }
          }
        ]
      }
    end
    
    it 'handles single point FeatureCollection from Firebase' do
      service = described_class.new(article, geojson_data: firebase_single_point_response)
      geodatum = service.create_or_update_geodata(source_type: 'custom_endpoint')
      
      expect(geodatum).to be_persisted
      expect(geodatum.geometry_type).to eq('Point')
      expect(geodatum.source_type).to eq('custom_endpoint')
    end
    
    it 'converts multiple points to LineString' do
      service = described_class.new(article, geojson_data: firebase_multiple_points_response)
      geodatum = service.create_or_update_geodata(source_type: 'custom_endpoint')
      
      expect(geodatum).to be_persisted
      # Multiple points should be converted to LineString
      expect(geodatum.geometry_type).to eq('LineString')
      
      # Check that the geojson_data contains the LineString
      stored_data = geodatum.geojson_data
      expect(stored_data['features'].first['geometry']['type']).to eq('LineString')
    end
    
    it 'preserves properties from multiple features' do
      service = described_class.new(article, geojson_data: firebase_multiple_points_response)
      geodatum = service.create_or_update_geodata
      
      stored_data = geodatum.geojson_data
      properties = stored_data['features'].first['properties']
      
      # Should have merged properties
      expect(properties['name']).to be_present
      expect(properties['feature_count']).to eq(3)
    end
  end
  
  describe '#process_geojson_response' do
    let(:service) { described_class.new(article) }
    
    it 'returns single point unchanged' do
      result = service.send(:process_geojson_response, firebase_single_point_response)
      
      expect(result['type']).to eq('FeatureCollection')
      expect(result['features'].length).to eq(1)
      expect(result['features'].first['geometry']['type']).to eq('Point')
    end
    
    it 'converts multiple points to LineString' do
      result = service.send(:process_geojson_response, firebase_multiple_points_response)
      
      expect(result['type']).to eq('FeatureCollection')
      expect(result['features'].length).to eq(1)
      expect(result['features'].first['geometry']['type']).to eq('LineString')
      expect(result['features'].first['geometry']['coordinates'].length).to eq(3)
    end
  end
end
