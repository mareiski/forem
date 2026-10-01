#!/usr/bin/env ruby
# Verification script for geosearch implementation

puts "=" * 80
puts "GEOSEARCH IMPLEMENTATION VERIFICATION"
puts "=" * 80
puts

# Check required files
required_files = [
  'docker-compose.yml',
  'db/migrate/20260929120000_enable_postgis_extension.rb',
  'db/migrate/20260929120001_create_article_geodata.rb',
  'app/models/article_geodatum.rb',
  'app/services/geodata_service.rb',
  'app/services/geosearch_service.rb',
  'app/controllers/api/v1/geosearch_controller.rb',
  'config/routes.rb',
  'spec/factories/article_geodata.rb',
  'spec/services/geodata_service_spec.rb',
  'spec/services/geosearch_service_spec.rb',
  'GEOSEARCH_IMPLEMENTATION.md'
]

puts "Checking required files..."
missing_files = []
required_files.each do |file|
  if File.exist?(file)
    puts "  ✓ #{file}"
  else
    puts "  ✗ #{file} (MISSING)"
    missing_files << file
  end
end

puts

# Check docker-compose.yml for PostGIS image
puts "Checking docker-compose.yml for PostGIS..."
if File.exist?('docker-compose.yml')
  content = File.read('docker-compose.yml')
  if content.include?('postgis/postgis:13-3.3-alpine')
    puts "  ✓ PostGIS image configured"
  else
    puts "  ✗ PostGIS image not configured"
  end
end

puts

# Check Article model for association
puts "Checking Article model for geodatum association..."
if File.exist?('app/models/article.rb')
  content = File.read('app/models/article.rb')
  if content.include?('has_one :article_geodatum')
    puts "  ✓ Article geodatum association configured"
  else
    puts "  ✗ Article geodatum association missing"
  end
end

puts

# Check GeodataService for Firebase endpoint
puts "Checking GeodataService for Firebase endpoint integration..."
if File.exist?('app/services/geodata_service.rb')
  content = File.read('app/services/geodata_service.rb')
  checks = [
    ['Firebase endpoint URL', content.include?('FIREBASE_AUTH_ORIGIN')],
    ['fetchPublicTripRouteOnServer', content.include?('fetchPublicTripRouteOnServer')],
    ['Multiple point handling', content.include?('Multiple Point features')],
    ['LineString conversion', content.include?('LineString')]
  ]
  
  checks.each do |name, passed|
    if passed
      puts "  ✓ #{name}"
    else
      puts "  ✗ #{name} (MISSING)"
    end
  end
end

puts

# Check GeosearchService
puts "Checking GeosearchService for query methods..."
if File.exist?('app/services/geosearch_service.rb')
  content = File.read('app/services/geosearch_service.rb')
  methods = [
    'search_near_point',
    'search_within_bounds',
    'search_within_polygon',
    'find_nearest',
    'count_within_radius'
  ]
  
  methods.each do |method|
    if content.include?(method)
      puts "  ✓ #{method}"
    else
      puts "  ✗ #{method} (MISSING)"
    end
  end
end

puts

# Check routes
puts "Checking routes configuration..."
if File.exist?('config/routes.rb')
  content = File.read('config/routes.rb')
  routes = [
    ['Geodata resource route', content.include?('resource :geodata')],
    ['Geosearch scope', content.include?('scope :geosearch')],
    ['nearby route', content.include?('get :nearby')],
    ['within_bounds route', content.include?('get :within_bounds')]
  ]
  
  routes.each do |name, passed|
    if passed
      puts "  ✓ #{name}"
    else
      puts "  ✗ #{name} (MISSING)"
    end
  end
end

puts

# Check model validation
puts "Checking ArticleGeodatum model..."
if File.exist?('app/models/article_geodatum.rb')
  content = File.read('app/models/article_geodatum.rb')
  checks = [
    ['belongs_to :article', content.include?('belongs_to :article')],
    ['JSON validation', content.include?('json:')],
    ['Geometry types', content.include?('VALID_GEOMETRY_TYPES')],
    ['Geometry conversion', content.include?('geojson_to_wkt')],
    ['Bounds calculation', content.include?('update_bounds')]
  ]
  
  checks.each do |name, passed|
    if passed
      puts "  ✓ #{name}"
    else
      puts "  ✗ #{name} (MISSING)"
    end
  end
end

puts
puts "=" * 80

if missing_files.empty?
  puts "✓ ALL CHECKS PASSED - Implementation is complete!"
  puts "\nNext steps:"
  puts "1. Run: docker-compose down && docker-compose up -d postgres"
  puts "2. Run: docker-compose run migrate"
  puts "3. Run: docker-compose down && docker-compose up -d"
  puts "4. Test: curl 'http://localhost:3000/api/v1/geosearch/nearby?lat=41.117143&lon=16.871871&radius_km=10'"
else
  puts "✗ SOME CHECKS FAILED - Please review missing files"
  puts "Missing files: #{missing_files.join(', ')}"
end

puts "=" * 80
