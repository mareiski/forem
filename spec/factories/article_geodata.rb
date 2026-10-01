FactoryBot.define do
  factory :article_geodatum do
    association :article
    
    # Default: NYC point
    geojson_data do
      {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [-73.9857, 40.7484]
        },
        properties: {
          name: 'New York City',
          timestamp: Time.current.iso8601
        }
      }
    end
    
    geometry_type { 'Point' }
    source_type { 'manual_entry' }
    source_metadata { {} }
    
    # Bounding box for NYC
    bounds_min_lon { -73.9857 }
    bounds_min_lat { 40.7484 }
    bounds_max_lon { -73.9857 }
    bounds_max_lat { 40.7484 }
    
    trait :with_line do
      geojson_data do
        {
          type: 'Feature',
          geometry: {
            type: 'LineString',
            coordinates: [
              [-73.9857, 40.7484],
              [-74.0060, 40.7128],
              [-74.05, 40.70]
            ]
          },
          properties: {
            name: 'NYC Route',
            distance_km: 5.5,
            timestamp: Time.current.iso8601
          }
        }
      end
      
      geometry_type { 'LineString' }
      
      # Bounding box for the line
      bounds_min_lon { -74.05 }
      bounds_min_lat { 40.70 }
      bounds_max_lon { -73.9857 }
      bounds_max_lat { 40.7484 }
    end
    
    trait :with_polygon do
      geojson_data do
        {
          type: 'Feature',
          geometry: {
            type: 'Polygon',
            coordinates: [[
              [-74.0, 40.7],
              [-74.0, 40.8],
              [-73.9, 40.8],
              [-73.9, 40.7],
              [-74.0, 40.7]
            ]]
          },
          properties: {
            name: 'NYC Area',
            timestamp: Time.current.iso8601
          }
        }
      end
      
      geometry_type { 'Polygon' }
      
      # Bounding box for the polygon
      bounds_min_lon { -74.0 }
      bounds_min_lat { 40.7 }
      bounds_max_lon { -73.9 }
      bounds_max_lat { 40.8 }
    end
    
    trait :from_custom_endpoint do
      source_type { 'custom_endpoint' }
      source_metadata { { endpoint: 'https://api.example.com/geodata', response_time: 120 } }
    end
  end
end
