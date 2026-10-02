class GeosearchService
  # Service for performing geospatial searches on articles
  
  # Earth's radius in kilometers for distance calculations
  EARTH_RADIUS_KM = 6_371.0
  
  # Default search radius in kilometers
  DEFAULT_SEARCH_RADIUS_KM = 10.0
  
  # Default limit for search results
  DEFAULT_SEARCH_LIMIT = 20
  
  # Result object for geosearch
  GeosearchResult = Struct.new(:article, :geodatum, :distance_meters, keyword_init: true) do
    def distance_km
      distance_meters / 1000.0
    end
  end
  
  def initialize
    # We'll use ActiveRecord queries with PostGIS functions
  end
  
  # Search for articles within a circular area (point + radius)
  # @param point [Array<Float, Float>] [longitude, latitude] of the center point
  # @param radius_km [Float] Search radius in kilometers
  # @param limit [Integer] Maximum number of results to return
  # @param offset [Integer] Pagination offset
  # @return [Array<GeosearchResult>] Articles within the radius, ordered by distance
  def search_within_radius(point, radius_km: DEFAULT_SEARCH_RADIUS_KM, limit: DEFAULT_SEARCH_LIMIT, offset: 0)
    longitude, latitude = point
    
    # Convert radius from km to degrees (approximate)
    # 1 degree of latitude ≈ 111.32 km
    # 1 degree of longitude ≈ 111.32 * cos(latitude) km
    radius_degrees = radius_km / 111.32
    
    # First, do a bounding box filter for efficiency
    min_lat = latitude - radius_degrees
    max_lat = latitude + radius_degrees
    
    # For longitude, we need to account for the latitude
    longitude_factor = 111.32 * Math.cos(latitude * Math::PI / 180)
    radius_degrees_lon = radius_km / longitude_factor
    
    min_lon = longitude - radius_degrees_lon
    max_lon = longitude + radius_degrees_lon
    
    # Use PostGIS ST_DWithin for precise distance calculation
    # We'll use the geography type for accurate distance measurements
    geodata = ArticleGeodatum
      .with_geometry
      .where("ST_DWithin(
        geography(geometry), 
        geography(ST_MakePoint(?, ?)),
        ?
      )", longitude, latitude, radius_km * 1000)
      .order(Arel.sql(distance_order_sql(longitude, latitude)))
      .limit(limit)
      .offset(offset)
      .includes(:article)
    
    # Convert to result objects with distance
    geodata.map do |gd|
      distance = calculate_distance(gd, [longitude, latitude])
      GeosearchResult.new(article: gd.article, geodatum: gd, distance_meters: distance)
    end
  end
  
  # Search for articles within a bounding box (rectangular area)
  # @param bounds [Hash] with :min_lon, :min_lat, :max_lon, :max_lat
  # @param limit [Integer] Maximum number of results
  # @param offset [Integer] Pagination offset
  # @return [Array<Article>] Articles within the bounding box
  def search_within_bounds(bounds, limit: DEFAULT_SEARCH_LIMIT, offset: 0)
    ArticleGeodatum
      .with_geometry
      .within_bounds(
        bounds[:min_lon], bounds[:min_lat], 
        bounds[:max_lon], bounds[:max_lat]
      )
      .limit(limit)
      .offset(offset)
      .includes(:article)
      .map(&:article)
  end
  
  # Search for articles within a polygon (country, region, etc.)
  # @param polygon_wkt [String] Well-Known Text representation of the polygon
  # @param limit [Integer] Maximum number of results
  # @param offset [Integer] Pagination offset
  # @return [Array<Article>] Articles within the polygon
  def search_within_polygon(polygon_wkt, limit: DEFAULT_SEARCH_LIMIT, offset: 0)
    ArticleGeodatum
      .with_geometry
      .where("ST_Within(geometry, ST_GeomFromText(?, 4326))", polygon_wkt)
      .limit(limit)
      .offset(offset)
      .includes(:article)
      .map(&:article)
  end
  
  # Search for articles near a point using ST_DWithin
  # This is more efficient for large datasets
  # @param point [Array<Float, Float>] [longitude, latitude]
  # @param radius_meters [Float] Search radius in meters
  # @param limit [Integer] Maximum number of results
  # @return [Array<GeosearchResult>] Articles within radius, ordered by distance
  def search_near_point(point, radius_meters: DEFAULT_SEARCH_RADIUS_KM * 1000, limit: DEFAULT_SEARCH_LIMIT)
    longitude, latitude = point
    
    geodata = ArticleGeodatum
      .with_geometry
      .where("ST_DWithin(
        geography(geometry), 
        geography(ST_MakePoint(?, ?)),
        ?
      )", longitude, latitude, radius_meters)
      .order(Arel.sql(distance_order_sql(longitude, latitude)))
      .limit(limit)
      .includes(:article)
    
    geodata.map do |gd|
      distance = calculate_distance(gd, [longitude, latitude])
      GeosearchResult.new(article: gd.article, geodatum: gd, distance_meters: distance)
    end
  end
  
  # Find the nearest articles to a point
  # @param point [Array<Float, Float>] [longitude, latitude]
  # @param limit [Integer] Maximum number of results
  # @return [Array<GeosearchResult>] Nearest articles, ordered by distance
  def find_nearest(point, limit: 5)
    longitude, latitude = point
    
    geodata = ArticleGeodatum
      .with_geometry
      .order(Arel.sql(distance_order_sql(longitude, latitude)))
      .limit(limit)
      .includes(:article)
    
    geodata.map do |gd|
      distance = calculate_distance(gd, [longitude, latitude])
      GeosearchResult.new(article: gd.article, geodatum: gd, distance_meters: distance)
    end
  end
  
  # Check if a point is within any article's geometry
  # Useful for "what's at this location?" queries
  # @param point [Array<Float, Float>] [longitude, latitude]
  # @param limit [Integer] Maximum number of results
  # @return [Array<GeosearchResult>] Articles that contain the point
  def find_at_point(point, limit: DEFAULT_SEARCH_LIMIT)
    longitude, latitude = point
    
    geodata = ArticleGeodatum
      .with_geometry
      .where("ST_Contains(geometry, ST_MakePoint(?, ?)) OR " \
             "ST_DWithin(geometry, ST_MakePoint(?, ?), 0.001)",
             longitude, latitude, longitude, latitude)
      .limit(limit)
      .includes(:article)
    
    geodata.map do |gd|
      distance = calculate_distance(gd, [longitude, latitude])
      GeosearchResult.new(article: gd.article, geodatum: gd, distance_meters: distance)
    end
  end
  
  # Get articles that have geodata
  # @param limit [Integer] Maximum number of results
  # @param offset [Integer] Pagination offset
  # @return [Array<Article>] Articles with geodata
  def articles_with_geodata(limit: DEFAULT_SEARCH_LIMIT, offset: 0)
    Article.joins(:article_geodatum).limit(limit).offset(offset)
  end
  
  # Count articles within a bounding box
  # @param bounds [Hash] with :min_lon, :min_lat, :max_lon, :max_lat
  # @return [Integer] Count of articles within bounds
  def count_within_bounds(bounds)
    ArticleGeodatum
      .with_geometry
      .within_bounds(
        bounds[:min_lon], bounds[:min_lat], 
        bounds[:max_lon], bounds[:max_lat]
      )
      .count
  end
  
  # Count articles within a radius
  # @param point [Array<Float, Float>] [longitude, latitude]
  # @param radius_km [Float] Search radius in kilometers
  # @return [Integer] Count of articles within radius
  def count_within_radius(point, radius_km: DEFAULT_SEARCH_RADIUS_KM)
    longitude, latitude = point
    
    ArticleGeodatum
      .with_geometry
      .where("ST_DWithin(
        geography(geometry), 
        geography(ST_MakePoint(?, ?)),
        ?
      )", longitude, latitude, radius_km * 1000)
      .count
  end
  
  private

  def distance_order_sql(longitude, latitude)
    ArticleGeodatum.sanitize_sql_array([
      "ST_Distance(geography(geometry), geography(ST_MakePoint(?, ?))) ASC",
      longitude,
      latitude,
    ])
  end
  
  # Calculate distance between geodatum and point in meters
  # Uses PostGIS ST_Distance function with geography type for accurate measurements
  def calculate_distance(geodatum, point)
    return 0 if geodatum.geometry.nil?
    
    longitude, latitude = point
    
    # Execute raw SQL to get the distance in meters
    sql = <<~SQL
      SELECT ST_Distance(
        geography(geometry), 
        geography(ST_MakePoint(#{longitude}, #{latitude}))
      ) AS distance
      FROM article_geodata
      WHERE id = #{geodatum.id}
    SQL
    
    result = ActiveRecord::Base.connection.execute(sql).first
    result['distance'].to_f
  rescue => e
    # Fallback: approximate distance using haversine formula
    calculate_haversine_distance(geodatum, point)
  end
  
  # Fallback distance calculation using Haversine formula
  def calculate_haversine_distance(geodatum, point)
    return 0 if geodatum.bounds_min_lon.nil?
    
    # Use the center of the bounds for point geometries, or the first point for lines
    if geodatum.geometry_type == 'Point'
      lon1, lat1 = geodatum.bounds_min_lon, geodatum.bounds_min_lat
    else
      # For lines, use the midpoint
      lon1 = (geodatum.bounds_min_lon + geodatum.bounds_max_lon) / 2.0
      lat1 = (geodatum.bounds_min_lat + geodatum.bounds_max_lat) / 2.0
    end
    
    lon2, lat2 = point
    
    # Convert to radians
    lat1_rad = lat1 * Math::PI / 180
    lon1_rad = lon1 * Math::PI / 180
    lat2_rad = lat2 * Math::PI / 180
    lon2_rad = lon2 * Math::PI / 180
    
    # Haversine formula
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    
    a = Math.sin(dlat / 2) * Math.sin(dlat / 2) + 
        Math.cos(lat1_rad) * Math.cos(lat2_rad) * 
        Math.sin(dlon / 2) * Math.sin(dlon / 2)
    
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    (EARTH_RADIUS_KM * c * 1000).round(2)
  end
end
