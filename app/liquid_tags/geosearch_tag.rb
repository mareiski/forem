class GeosearchTag < LiquidTagBase
  PARTIAL = "liquids/geosearch".freeze
  DEFAULT_LIMIT = 8
  MAX_LIMIT = 30
  MAX_RADIUS_KM = 500
  INPUT_REGEXP = /\A\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)(?:\s+limit=(\d+))?\s*\z/

  def initialize(_tag_name, input, _parse_context)
    super
    match = input.to_s.match(INPUT_REGEXP)
    raise StandardError, "Invalid geosearch. Use: {% geosearch latitude,longitude radius_km [limit=N] %}" unless match

    @latitude = match[1].to_f
    @longitude = match[2].to_f
    @radius_km = match[3].to_f
    @limit = (match[4] || DEFAULT_LIMIT).to_i

    validate_coordinates
    validate_radius
    validate_limit
  end

  def render(_context)
    results = GeosearchService.new.search_within_radius(
      [@longitude, @latitude],
      radius_km: @radius_km,
      limit: @limit,
    )
    articles = ArticleDecorator.decorate_collection(results.map(&:article))
    rendered_results = results.zip(articles).map do |result, article|
      { article: article, distance_km: format("%.1f", result.distance_km) }
    end

    ApplicationController.render(
      partial: PARTIAL,
      locals: { results: rendered_results },
    )
  end

  private

  def validate_coordinates
    return if @latitude.between?(-90, 90) && @longitude.between?(-180, 180)

    raise StandardError, "Geosearch coordinates must be latitude -90..90 and longitude -180..180"
  end

  def validate_radius
    return if @radius_km.positive? && @radius_km <= MAX_RADIUS_KM

    raise StandardError, "Geosearch radius must be greater than 0 and at most #{MAX_RADIUS_KM} km"
  end

  def validate_limit
    return if @limit.between?(1, MAX_LIMIT)

    raise StandardError, "Geosearch limit must be between 1 and #{MAX_LIMIT}"
  end
end

Liquid::Template.register_tag("geosearch", GeosearchTag)