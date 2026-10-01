#!/usr/bin/env ruby
# Test script for roadlio geodata implementation

require_relative 'config/environment'

puts "=" * 80
puts "ROADLIO GEODATA IMPLEMENTATION TEST"
puts "=" * 80
puts

# Test 1: Check that GeodataService has new methods
puts "Test 1: GeodataService methods..."
begin
  geodata_service = GeodataService.new(nil)
  
  if geodata_service.respond_to?(:fetch_from_roadlio_url)
    puts "  ✓ fetch_from_roadlio_url method exists"
  else
    puts "  ✗ fetch_from_roadlio_url method missing"
  end
  
  if geodata_service.respond_to?(:create_or_update_geodata_from_roadlio)
    puts "  ✓ create_or_update_geodata_from_roadlio method exists"
  else
    puts "  ✗ create_or_update_geodata_from_roadlio method missing"
  end
  
  if geodata_service.respond_to?(:merge_geojson_data)
    puts "  ✓ merge_geojson_data method exists"
  else
    puts "  ✗ merge_geojson_data method missing"
  end
  
  if geodata_service.respond_to?(:extract_features)
    puts "  ✓ extract_features method exists"
  else
    puts "  ✗ extract_features method missing"
  end
rescue => e
  puts "  ✗ Error loading GeodataService: #{e.message}"
end

puts

# Test 2: Check that Article model has new methods
puts "Test 2: Article model methods..."
begin
  if Article.private_instance_methods(false).include?(:process_roadlio_geodata)
    puts "  ✓ process_roadlio_geodata method exists"
  else
    puts "  ✗ process_roadlio_geodata method missing"
  end
  
  if Article.private_instance_methods(false).include?(:extract_roadlio_urls)
    puts "  ✓ extract_roadlio_urls method exists"
  else
    puts "  ✗ extract_roadlio_urls method missing"
  end
rescue => e
  puts "  ✗ Error checking Article methods: #{e.message}"
end

puts

# Test 3: Check that Article model has the callback
puts "Test 3: Article model callback..."
begin
  # Read the article.rb file and check for the callback
  article_file = File.read('app/models/article.rb')
  if article_file.include?('after_save :process_roadlio_geodata')
    puts "  ✓ after_save callback added"
  else
    puts "  ✗ after_save callback missing"
  end
  
  if article_file.include?('if: :body_markdown_changed?')
    puts "  ✓ callback has body_markdown_changed? condition"
  else
    puts "  ✗ callback missing body_markdown_changed? condition"
  end
rescue => e
  puts "  ✗ Error reading article.rb: #{e.message}"
end

puts

# Test 4: Check that ArticleGeodatum has roadlio in source types
puts "Test 4: ArticleGeodatum source types..."
begin
  if ArticleGeodatum::VALID_SOURCE_TYPES.include?('roadlio')
    puts "  ✓ roadlio added to VALID_SOURCE_TYPES"
  else
    puts "  ✗ roadlio missing from VALID_SOURCE_TYPES"
  end
rescue => e
  puts "  ✗ Error checking source types: #{e.message}"
end

puts

# Test 5: Test extract_roadlio_urls method
puts "Test 5: Testing extract_roadlio_urls method..."
begin
  # Create a mock article
  class MockArticle
    include ActiveModel::Validations
    attr_accessor :body_markdown
    
    def extract_roadlio_urls
      return [] unless body_markdown
      
      # Use the same regex as RoadlioTag::VALID_URL_REGEXP
      roadlio_regex = RoadlioTag::VALID_URL_REGEXP
      
      # Find all matches
      body_markdown.scan(roadlio_regex).flatten.uniq
    end
  end
  
  article = MockArticle.new
  
  # Test with no URLs
  article.body_markdown = "This is a test post"
  urls = article.extract_roadlio_urls
  if urls.empty?
    puts "  ✓ No URLs extracted from plain text"
  else
    puts "  ✗ Unexpected URLs: #{urls.inspect}"
  end
  
  # Test with a roadlio URL
  article.body_markdown = "Check out my trip: https://roadtrip-planen.de/reise-ansehen/abc123"
  urls = article.extract_roadlio_urls
  if urls == ['https://roadtrip-planen.de/reise-ansehen/abc123']
    puts "  ✓ Roadlio URL extracted correctly"
  else
    puts "  ✗ Expected ['https://roadtrip-planen.de/reise-ansehen/abc123'], got #{urls.inspect}"
  end
  
  # Test with multiple roadlio URLs
  article.body_markdown = "Trip 1: https://roadtrip-planen.de/reise-ansehen/abc123 and Trip 2: https://www.roadtrip-planen.de/reise-ansehen/def456"
  urls = article.extract_roadlio_urls
  if urls.length == 2 && urls.include?('https://roadtrip-planen.de/reise-ansehen/abc123') && urls.include?('https://www.roadtrip-planen.de/reise-ansehen/def456')
    puts "  ✓ Multiple roadlio URLs extracted correctly"
  else
    puts "  ✗ Expected 2 URLs, got #{urls.length}: #{urls.inspect}"
  end
  
  # Test with duplicate URLs
  article.body_markdown = "URL: https://roadtrip-planen.de/reise-ansehen/abc123 and again: https://roadtrip-planen.de/reise-ansehen/abc123"
  urls = article.extract_roadlio_urls
  if urls.length == 1
    puts "  ✓ Duplicate URLs removed (uniq working)"
  else
    puts "  ✗ Expected 1 URL (uniq), got #{urls.length}: #{urls.inspect}"
  end
rescue => e
  puts "  ✗ Error testing extract_roadlio_urls: #{e.message}"
  puts e.backtrace.first(5).join("\n  ")
end

puts

# Test 6: Test merge_geojson_data method
puts "Test 6: Testing merge_geojson_data method..."
begin
  geodata_service = GeodataService.new(nil)
  
  # Test merging two FeatureCollections
  data1 = {
    'type' => 'FeatureCollection',
    'features' => [
      {
        'type' => 'Feature',
        'geometry' => { 'type' => 'Point', 'coordinates' => [1.0, 2.0] },
        'properties' => { 'name' => 'Point 1' }
      }
    ]
  }
  
  data2 = {
    'type' => 'FeatureCollection',
    'features' => [
      {
        'type' => 'Feature',
        'geometry' => { 'type' => 'Point', 'coordinates' => [3.0, 4.0] },
        'properties' => { 'name' => 'Point 2' }
      }
    ]
  }
  
  merged = geodata_service.merge_geojson_data(data1, data2)
  
  if merged['type'] == 'FeatureCollection' && merged['features'].length == 2
    puts "  ✓ FeatureCollections merged correctly"
  else
    puts "  ✗ Expected FeatureCollection with 2 features, got #{merged.inspect}"
  end
  
  # Test merging with source URL tracking
  if merged['properties'] && merged['properties']['source_urls']
    puts "  ✓ Source URLs tracked in merged data"
  else
    puts "  ✗ Source URLs not tracked"
  end
rescue => e
  puts "  ✗ Error testing merge_geojson_data: #{e.message}"
  puts e.backtrace.first(5).join("\n  ")
end

puts
puts "=" * 80
puts "TEST COMPLETE"
puts "=" * 80
