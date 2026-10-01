require 'rails_helper'

RSpec.describe GeodataService, type: :service do
  let(:user) { create(:user) }
  let(:article) { create(:article, user: user) }
  
  describe '#create_or_update_geodata' do
    it 'creates geodata from GeoJSON point' do
      geojson = {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [-73.9857, 40.7484]
        },
        properties: { name: 'Test Point' }
      }
      
      service = described_class.new(article, geojson_data: geojson)
      geodatum = service.create_or_update_geodata(source_type: 'test')
      
      expect(geodatum).to be_persisted
      expect(geodatum.article).to eq(article)
      expect(geodatum.geojson_data).to eq(geojson)
      expect(geodatum.geometry_type).to eq('Point')
      expect(geodatum.source_type).to eq('test')
    end
    
    it 'creates geodata from GeoJSON line' do
      geojson = {
        type: 'Feature',
        geometry: {
          type: 'LineString',
          coordinates: [
            [-73.9857, 40.7484],
            [-74.0060, 40.7128]
          ]
        },
        properties: { name: 'Test Line' }
      }
      
      service = described_class.new(article, geojson_data: geojson)
      geodatum = service.create_or_update_geodata
      
      expect(geodatum).to be_persisted
      expect(geodatum.geometry_type).to eq('LineString')
    end
    
    it 'updates existing geodata' do
      # Create initial geodata
      initial_geojson = {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [0, 0]
        }
      }
      
      service = described_class.new(article, geojson_data: initial_geojson)
      geodatum = service.create_or_update_geodata
      
      # Update with new data
      updated_geojson = {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [1, 1]
        }
      }
      
      service = described_class.new(article, geojson_data: updated_geojson)
      geodatum = service.create_or_update_geodata
      
      expect(geodatum.geojson_data).to eq(updated_geojson)
    end
    
    it 'raises error for invalid GeoJSON' do
      invalid_geojson = { type: 'Invalid' }
      
      service = described_class.new(article, geojson_data: invalid_geojson)
      
      expect {
        service.create_or_update_geodata
      }.to raise_error(GeodataService::InvalidGeoJSONError)
    end
    
    it 'fetches from mock endpoint when no data provided' do
      service = described_class.new(article)
      geodatum = service.create_or_update_geodata
      
      expect(geodatum).to be_persisted
      expect(geodatum.geojson_data).to be_present
    end
  end
  
  describe '#remove_geodata' do
    it 'removes geodata from article' do
      geojson = {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [0, 0]
        }
      }
      
      service = described_class.new(article, geojson_data: geojson)
      geodatum = service.create_or_update_geodata
      
      expect(article.article_geodatum).to be_present
      
      service.remove_geodata
      
      expect(article.reload.article_geodatum).to be_nil
    end
  end
  
  describe '#get_geodata' do
    it 'returns geodata for article' do
      geojson = {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [0, 0]
        }
      }
      
      service = described_class.new(article, geojson_data: geojson)
      geodatum = service.create_or_update_geodata
      
      result = service.get_geodata
      
      expect(result).to eq(geodatum)
    end
    
    it 'returns nil when no geodata exists' do
      service = described_class.new(article)
      
      expect(service.get_geodata).to be_nil
    end
  end
end
