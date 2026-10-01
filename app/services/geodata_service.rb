class GeodataService
  # Service to fetch and store geodata from custom endpoints
  # Fetches from: ENV['FIREBASE_AUTH_ORIGIN'] + '/utility/fetchPublicTripRouteOnServer'
  
  # Default endpoint URL
  DEFAULT_ENDPOINT = lambda do
    url = ENV['FIREBASE_AUTH_ORIGIN']
    url = url.chomp('/') if url
    "#{url}/utility/fetchPublicTripRouteOnServer"
  end
  
  # Error class for geodata operations
  class GeodataError < StandardError; end
  
  # Error class for fetch failures
  class FetchError < GeodataError; end
  
  # Error class for invalid GeoJSON
  class InvalidGeoJSONError < GeodataError; end
  
  # Error class for unsupported geometry
  class UnsupportedGeometryError < GeodataError; end
  
  def initialize(article, geojson_data: nil, endpoint_url: nil, url: nil)
    @article = article
    @geojson_data = geojson_data
    @endpoint_url = endpoint_url || DEFAULT_ENDPOINT.call
    @url = url
  end
  
  # Fetch geodata from the Firebase custom endpoint
  # Expected response format (from the user's endpoint):
  # {
  #   "type": "FeatureCollection",
  #   "features": [
  #     {
  #       "type": "Feature",
  #       "geometry": { "type": "Point", "coordinates": [16.871871, 41.117143] },
  #       "properties": { "name": "Bari" }
  #     },
  #     {
  #       "type": "Feature",
  #       "geometry": { "type": "Point", "coordinates": [16.88, 41.12] },
  #       "properties": { "name": "Another Point" }
  #     }
  #   ]
  # }
  # If multiple Point features are returned, they will be converted to a LineString
  # representing a route.
  def fetch_from_endpoint
    require 'net/http'
    require 'uri'
    require 'json'
    
    uri = URI.parse(@endpoint_url)
    
    # Make GET request to the Firebase endpoint
    response = Net::HTTP.get_response(uri)
    
    unless response.code == '200'
      raise FetchError, "Failed to fetch from #{@endpoint_url}: HTTP #{response.code} - #{response.message}"
    end
    
    data = JSON.parse(response.body)
    
    # Process the FeatureCollection - if it has multiple points, convert to LineString
    process_geojson_response(data)
    
  rescue JSON::ParserError => e
    raise FetchError, "Invalid JSON response: #{e.message}"
  rescue StandardError => e
    raise FetchError, "Failed to fetch geodata: #{e.message}"
  end
  
  # Fetch geodata from fetchPublicTrip endpoint with a specific URL
  # This is used for roadlio tags
  # @param url [String] The roadlio URL to fetch geodata for
  # @return [Hash] Processed GeoJSON data
  def fetch_from_roadlio_url(url)
    require 'net/http'
    require 'uri'
    require 'json'
    
    # Validate that the URL matches the expected host from RoadlioTag
    valid_url_regexp = RoadlioTag.valid_url_regexp
    unless url.match?(valid_url_regexp)
      raise FetchError, "Invalid roadlio URL: #{url}. Expected URLs matching #{valid_url_regexp.inspect}"
    end
    
    # Build the fetchPublicTrip endpoint URL
    firebase_url = ENV['FIREBASE_AUTH_ORIGIN']
    unless firebase_url
      raise FetchError, "FIREBASE_AUTH_ORIGIN environment variable not set"
    end
    
    firebase_url = firebase_url.chomp('/')
    endpoint = "#{firebase_url}/utility/fetchPublicTrip"
    
    # Add the URL as a query parameter
    uri = URI.parse(endpoint)
    uri.query = URI.encode_www_form({ url: url })
    
    # Make GET request
    response = Net::HTTP.get_response(uri)
    
    unless response.code == '200'
      raise FetchError, "Failed to fetch from #{endpoint}?#{uri.query}: HTTP #{response.code} - #{response.message}"
    end
    
    data = JSON.parse(response.body)
    
    # Process the FeatureCollection - if it has multiple points, convert to LineString
    process_geojson_response(data)
    
  rescue JSON::ParserError => e
    raise FetchError, "Invalid JSON response from fetchPublicTrip: #{e.message}"
  rescue StandardError => e
    raise FetchError, "Failed to fetch geodata from fetchPublicTrip: #{e.message}"
  end
  
  # Process the endpoint response
  # If we have multiple Point features, we can optionally convert them to a LineString
  # This handles both single points and routes
  def process_geojson_response(data)
    return data unless data.is_a?(Hash)
    
    case data['type']
    when 'FeatureCollection'
      features = data['features'] || []
      
      # If we have multiple point features, we can create a LineString from them
      if features.length > 1
        point_features = features.select { |f| f.dig('geometry', 'type') == 'Point' }
        
        # If we have 2+ points, create a LineString
        if point_features.length >= 2
          coordinates = point_features.map { |f| f.dig('geometry', 'coordinates') }.compact
          
          # Create a LineString feature
          line_feature = {
            'type' => 'Feature',
            'geometry' => {
              'type' => 'LineString',
              'coordinates' => coordinates
            },
            'properties' => {
              'name' => data['properties']&.[]('name') || 'Route',
              'feature_count' => features.length,
              'original_type' => 'MultiPoint',
              'timestamp' => Time.current.iso8601
            }.merge(merge_properties(features))
          }
          
          return {
            'type' => 'FeatureCollection',
            'features' => [line_feature],
            'properties' => data['properties']
          }
        end
      end
      
      # Return as-is if single feature or non-point features
      data
      
    when 'Feature'
      # Single feature - return as-is
      data
      
    else
      # Direct geometry or other - return as-is
      data
    end
  end
  
  # Merge properties from multiple features
  def merge_properties(features)
    merged = {}
    features.each do |feature|
      props = feature['properties'] || {}
      props.each { |k, v| merged[k] = v }
    end
    merged
  end
  
  # Create or update geodata for an article
  # @param geojson_data [Hash] GeoJSON data to store
  # @param source_type [String] Type of source (default: 'custom_endpoint')
  # @param source_metadata [Hash] Additional metadata about the source
  # @return [ArticleGeodatum] The created or updated geodatum
  def create_or_update_geodata(geojson_data: nil, source_type: 'custom_endpoint', source_metadata: nil)
    data = geojson_data || @geojson_data
    data ||= fetch_from_endpoint if @url.nil? && @endpoint_url
    
    raise FetchError, 'No GeoJSON data provided and no endpoint configured' unless data
    
    # Find or initialize the geodatum
    geodatum = @article.article_geodatum || ArticleGeodatum.new(article: @article)
    
    # Set the data
    geodatum.geojson_data = data
    geodatum.source_type = source_type
    geodatum.source_metadata = source_metadata || {}
    
    # Validate and save
    unless geodatum.valid?
      raise InvalidGeoJSONError, "Invalid GeoJSON: #{geodatum.errors.full_messages.join(', ')}"
    end
    
    geodatum.save!
    geodatum
  end
  
  # Create or update geodata for an article from a roadlio URL
  # @param roadlio_url [String] The roadlio URL to fetch geodata from
  # @param source_metadata [Hash] Additional metadata about the source
  # @return [ArticleGeodatum] The created or updated geodatum
  def create_or_update_geodata_from_roadlio(roadlio_url, source_metadata: nil)
    raise FetchError, 'No roadlio URL provided' unless roadlio_url
    
    # Add URL parameter to the source metadata for tracking
    effective_metadata = source_metadata || {}
    effective_metadata[:roadlio_url] = roadlio_url
    effective_metadata[:timestamp] = Time.current.iso8601
    
    data = fetch_from_roadlio_url(roadlio_url)
    
    # Add source URL to data properties for tracking
    data['properties'] ||= {}
    data['properties']['source_url'] = roadlio_url
    data['properties']['source_urls'] ||= []
    data['properties']['source_urls'] << roadlio_url
    
    # Find or initialize the geodatum
    geodatum = @article.article_geodatum || ArticleGeodatum.new(article: @article)
    
    # If we already have geodata, merge the new data with existing
    if geodatum.geojson_data.present?
      data = merge_geojson_data(geodatum.geojson_data, data)
    end
    
    # Set the data
    geodatum.geojson_data = data
    geodatum.source_type = 'roadlio'
    geodatum.source_metadata = effective_metadata
    
    # Validate and save
    unless geodatum.valid?
      raise InvalidGeoJSONError, "Invalid GeoJSON: #{geodatum.errors.full_messages.join(', ')}"
    end
    
    geodatum.save!
    geodatum
  end
  
  # Merge multiple GeoJSON data sources
  # @param existing_data [Hash] Existing GeoJSON data
  # @param new_data [Hash] New GeoJSON data to merge
  # @return [Hash] Merged GeoJSON FeatureCollection
  def merge_geojson_data(existing_data, new_data)
    # Ensure both are FeatureCollections
    existing_features = extract_features(existing_data)
    new_features = extract_features(new_data)
    
    # Combine features
    all_features = existing_features + new_features
    
    # For PostGIS, we need to create a geometry that can be indexed
    # We'll create a FeatureCollection with all features for storage,
    # and the ArticleGeodatum model will handle extracting a single geometry
    # for the PostGIS column
    
    # Create a new FeatureCollection
    {
      'type' => 'FeatureCollection',
      'features' => all_features,
      'properties' => {
        'merged_from_multiple_sources' => true,
        'feature_count' => all_features.length,
        'timestamp' => Time.current.iso8601,
        'source_urls' => Array(existing_data['properties']&.[]('source_urls')) + Array(new_data['properties']&.[]('source_urls'))
      }
    }
  end
  
  # Extract features from GeoJSON data
  # @param data [Hash] GeoJSON data
  # @return [Array<Hash>] Array of features
  def extract_features(data)
    return [] unless data.is_a?(Hash)
    
    case data['type']
    when 'FeatureCollection'
      data['features'] || []
    when 'Feature'
      [data]
    when *ArticleGeodatum::VALID_GEOMETRY_TYPES
      # Direct geometry - wrap in a Feature
      [
        {
          'type' => 'Feature',
          'geometry' => data,
          'properties' => {}
        }
      ]
    else
      []
    end
  end
  
  # Remove geodata from an article
  def remove_geodata
    @article.article_geodatum&.destroy
    true
  end
  
  # Get geodata for an article
  # @return [ArticleGeodatum, nil]
  def get_geodata
    @article.article_geodatum
  end
end
