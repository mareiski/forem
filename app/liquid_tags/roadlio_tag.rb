class RoadlioTag < LiquidTagBase
  PARTIAL = "liquids/roadlio".freeze
  DEFAULT_ORIGIN = "https://roadtrip-planen.de".freeze

  # Roadlio URLs normally point to the public production viewer. During local
  # development, also accept the configured local origin, including its port.
  def self.local_origin
    configured_origin = ENV["ROADLIO_ORIGIN"].presence
    configured_origin ||= ENV["FIREBASE_AUTH_ORIGIN"].presence unless ENV["RAILS_ENV"] == "production"
    configured_origin&.chomp("/")
  end

  def self.origins
    [DEFAULT_ORIGIN, "https://www.roadtrip-planen.de", local_origin].compact.uniq
  end

  # Keep the host method for callers that use it for display or compatibility.
  def self.host
    URI.parse(local_origin || DEFAULT_ORIGIN).host
  end

  def self.registry_regexp
    %r{\A(?:#{origins.map { |origin| Regexp.escape(origin) }.join("|")})/reise-ansehen/[^\r\n]+}
  end

  def self.valid_url_regexp
    %r{\A(?:#{origins.map { |origin| Regexp.escape(origin) }.join("|")})/reise-ansehen/[^\r\n]+\z}
  end

  # Constants for backwards compatibility
  REGISTRY_REGEXP = registry_regexp
  VALID_URL_REGEXP = valid_url_regexp

  def initialize(_tag_name, input, _parse_context)
    super
    @url = strip_tags(input)
    raise StandardError, I18n.t("liquid_tags.roadlio_tag.invalid_url") unless @url.match?(self.class.valid_url_regexp)
  end

  def render(_context)
    ApplicationController.render(
      partial: PARTIAL,
      locals: { url: @url },
    )
  end
end

Liquid::Template.register_tag("roadlio", RoadlioTag)

UnifiedEmbed.register(RoadlioTag, regexp: RoadlioTag.registry_regexp)
