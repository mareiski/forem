class ArticleGeodatum < ApplicationRecord
  belongs_to :article, inverse_of: :article_geodatum
  
  # Valid geometry types for GeoJSON
  VALID_GEOMETRY_TYPES = %w[Point LineString Polygon MultiPoint MultiLineString MultiPolygon].freeze
  
  # Valid source types
  VALID_SOURCE_TYPES = %w[custom_endpoint manual_entry gps_track api_import roadlio].freeze
  
  validates :article, presence: true, uniqueness: true
  validates :geojson_data, presence: true
  validates :geometry_type, presence: true, inclusion: { in: VALID_GEOMETRY_TYPES }
  validates :source_type, inclusion: { in: VALID_SOURCE_TYPES, allow_nil: true }
  
  # Validate GeoJSON structure
  validate :validate_geojson_structure
  
  # Callback to update geometry and bounds when geojson_data changes
  before_validation :set_geometry_type_and_column
  before_save :update_bounds
  
  # Scope for articles with geodata
  scope :with_geometry, -> { where.not(geometry: nil) }
  
  # Scope to find articles within a bounding box
  scope :within_bounds, ->(min_lon, min_lat, max_lon, max_lat) do
    where(
      "bounds_min_lon >= ? AND bounds_min_lat >= ? AND " \
      "bounds_max_lon <= ? AND bounds_max_lat <= ?",
      min_lon, min_lat, max_lon, max_lat
    )
  end
  
  private
  
  def validate_geojson_structure
    return if geojson_data.blank?
    
    geojson = geojson_data.with_indifferent_access
    
    # Must have type and features/coordinates
    unless geojson[:type].present?
      errors.add(:geojson_data, 'must have a type field')
      return
    end
    
    # Handle FeatureCollection, Feature, or direct geometry
    case geojson[:type]
    when 'FeatureCollection'
      unless geojson[:features].is_a?(Array)
        errors.add(:geojson_data, 'FeatureCollection must have features array')
        return
      end
      
      # Allow empty FeatureCollections (shouldn't happen in practice)
      if geojson[:features].empty?
        errors.add(:geojson_data, 'FeatureCollection must have at least one feature')
        return
      end
      
      # We support FeatureCollections with one or more features
      # Each feature should have a valid geometry
      features = geojson[:features].map { |feature| feature.with_indifferent_access }
      features.each_with_index do |feature, index|
        
        geom = feature[:geometry]&.with_indifferent_access
        unless geom && geom[:type].present? && geom[:coordinates].present?
          errors.add(:geojson_data, "Feature at index #{index} must have valid geometry")
          return
        end
        
        unless VALID_GEOMETRY_TYPES.include?(geom[:type])
          errors.add(:geojson_data, "Feature at index #{index} has unsupported geometry type: #{geom[:type]}")
          return
        end
      end
      
    when 'Feature'
      validate_geometry_object(geojson[:geometry])
      
    when 'Point', 'LineString', 'Polygon', 'MultiPoint', 'MultiLineString', 'MultiPolygon'
      # Direct geometry object
      validate_geometry_object(geojson)
      
    else
      errors.add(:geojson_data, "unsupported GeoJSON type: #{geojson[:type]}")
    end
  end
  
  def validate_geometry_object(geometry)
    return unless geometry

    geometry = geometry.with_indifferent_access
    
    unless geometry[:type].present? && geometry[:coordinates].present?
      errors.add(:geojson_data, 'geometry must have type and coordinates')
      return
    end
    
    unless VALID_GEOMETRY_TYPES.include?(geometry[:type])
      errors.add(:geojson_data, "unsupported geometry type: #{geometry[:type]}")
    end
  end
  
  def set_geometry_type_and_column
    return unless geojson_data.present?
    
    geojson = geojson_data.with_indifferent_access
    
    # Extract the geometry object from the GeoJSON
    geometry_obj = extract_geometry_object(geojson)
    return unless geometry_obj
    
    # Set geometry_type based on the extracted geometry
    self.geometry_type = geometry_obj[:type]
    
    # Convert to WKT (Well-Known Text) format for PostGIS
    wkt = geojson_to_wkt(geometry_obj)
    
    # Store WKT string - will be converted to geometry by PostgreSQL or by after_save callback
    self.geometry = wkt
  end
  

  # Alias for backwards compatibility
  alias_method :update_geometry_column, :set_geometry_type_and_column
  
  def update_bounds
    return unless geojson_data.present?
    
    geojson = geojson_data.with_indifferent_access
    geometry_obj = extract_geometry_object(geojson)
    return unless geometry_obj
    
    coordinates = geometry_obj[:coordinates]
    
    case geometry_obj[:type]
    when 'Point'
      # Single point: [longitude, latitude]
      lon, lat = coordinates
      self.bounds_min_lon = lon
      self.bounds_min_lat = lat
      self.bounds_max_lon = lon
      self.bounds_max_lat = lat
      
    when 'LineString'
      # Line: [[lon, lat], [lon, lat], ...]
      all_coords = coordinates.flatten
      lons = all_coords.each_slice(2).map(&:first)
      lats = all_coords.each_slice(2).map(&:last)
      
      self.bounds_min_lon = lons.min
      self.bounds_min_lat = lats.min
      self.bounds_max_lon = lons.max
      self.bounds_max_lat = lats.max
      
    when 'Polygon'
      # Polygon: [[[lon, lat], [lon, lat], ...]]
      # Take the exterior ring (first ring)
      all_coords = geometry_obj[:coordinates].first.flatten
      lons = all_coords.each_slice(2).map(&:first)
      lats = all_coords.each_slice(2).map(&:last)
      
      self.bounds_min_lon = lons.min
      self.bounds_min_lat = lats.min
      self.bounds_max_lon = lons.max
      self.bounds_max_lat = lats.max
      
    when 'MultiPoint', 'MultiLineString', 'MultiPolygon'
      # Handle multi-geometries by computing bounds across all geometries
      all_coords = []
      geometry_obj[:coordinates].each do |coord|
        if geometry_obj[:type] == 'MultiPoint'
          all_coords.concat(coord)
        else
          # For MultiLineString and MultiPolygon, we need to flatten deeply
          all_coords.concat(flatten_coordinates(coord))
        end
      end
      
      lons = all_coords.each_slice(2).map(&:first)
      lats = all_coords.each_slice(2).map(&:last)
      
      self.bounds_min_lon = lons.min
      self.bounds_min_lat = lats.min
      self.bounds_max_lon = lons.max
      self.bounds_max_lat = lats.max
    end
  end
  
  def extract_geometry_object(geojson)
    case geojson[:type]
    when 'FeatureCollection'
      features = geojson[:features] || []
      
      # If we have a single feature, extract its geometry
      if features.length == 1
        return features.first&.with_indifferent_access&.[](:geometry)
      end
      
      # If we have multiple features, we need to handle them
      # Extract all geometries from features
      geometries = features.map { |feature| feature.with_indifferent_access[:geometry] }.compact
      
      if geometries.empty?
        return nil
      elsif geometries.length == 1
        return geometries.first
      else
        # Multiple geometries - check if they're all the same type
        # If so, create a Multi* geometry
        geometry_types = geometries.map { |g| g[:type] }.uniq
        
        if geometry_types.length == 1
          type = geometry_types.first
          case type
          when 'Point'
            return { type: 'MultiPoint', coordinates: geometries.map { |g| g[:coordinates] } }
          when 'LineString'
            return { type: 'MultiLineString', coordinates: geometries.map { |g| g[:coordinates] } }
          when 'Polygon'
            return { type: 'MultiPolygon', coordinates: geometries.map { |g| g[:coordinates] } }
          else
            # For other types, just take the first geometry
            return geometries.first
          end
        else
          # Mixed geometry types - take the first geometry as fallback
          return geometries.first
        end
      end
      
    when 'Feature'
      geojson[:geometry]
    when *VALID_GEOMETRY_TYPES
      geojson
    else
      nil
    end
  end
  
  def geojson_to_wkt(geometry_obj)
    case geometry_obj[:type]
    when 'Point'
      coord = geometry_obj[:coordinates]
      "POINT(#{coord[0]} #{coord[1]})"
    when 'LineString'
      coords = geometry_obj[:coordinates].map { |c| "#{c[0]} #{c[1]}" }.join(', ')
      "LINESTRING(#{coords})"
    when 'Polygon'
      # For polygon, use the exterior ring
      ring = geometry_obj[:coordinates].first
      coords = ring.map { |c| "#{c[0]} #{c[1]}" }.join(', ')
      "POLYGON((#{coords}))"
    when 'MultiPoint'
      coords = geometry_obj[:coordinates].map { |c| "(#{c[0]} #{c[1]})" }.join(', ')
      "MULTIPOINT(#{coords})"
    when 'MultiLineString'
      lines = geometry_obj[:coordinates].map do |line|
        coords = line.map { |c| "#{c[0]} #{c[1]}" }.join(', ')
        "(#{coords})"
      end.join(', ')
      "MULTILINESTRING(#{lines})"
    when 'MultiPolygon'
      polygons = geometry_obj[:coordinates].map do |polygon|
        rings = polygon.map do |ring|
          coords = ring.map { |c| "#{c[0]} #{c[1]}" }.join(', ')
          "(#{coords})"
        end.join(', ')
        "(#{rings})"
      end.join(', ')
      "MULTIPOLYGON(#{polygons})"
    else
      nil
    end
  end
  
  def flatten_coordinates(coord)
    if coord.first.is_a?(Array)
      coord.flatten(1)
    else
      [coord]
    end
  end
end
