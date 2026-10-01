#!/usr/bin/env ruby
# Test script for dynamic host configuration in RoadlioTag

require_relative 'config/environment'

puts "=" * 80
puts "DYNAMIC HOST CONFIGURATION TEST"
puts "=" * 80
puts

# Test 1: Check RoadlioTag host detection
puts "Test 1: RoadlioTag host detection..."

# Save current ENV value
original_env = ENV['FIREBASE_AUTH_ORIGIN']

# Test with default (no ENV set)
ENV.delete('FIREBASE_AUTH_ORIGIN')
RoadlioTag.instance_variable_set(:@host, nil) # Clear cached value

if RoadlioTag.host == 'roadtrip-planen.de'
  puts "  ✓ Default host is roadtrip-planen.de"
else
  puts "  ✗ Expected 'roadtrip-planen.de', got '#{RoadlioTag.host}'"
end

# Test with custom host
ENV['FIREBASE_AUTH_ORIGIN'] = 'http://localhost:3000'
RoadlioTag.instance_variable_set(:@host, nil) # Clear cached value

if RoadlioTag.host == 'localhost'
  puts "  ✓ Custom host 'localhost' detected from ENV"
else
  puts "  ✗ Expected 'localhost', got '#{RoadlioTag.host}'"
end

# Test with https URL
ENV['FIREBASE_AUTH_ORIGIN'] = 'https://my-firebase-app.firebaseapp.com'
RoadlioTag.instance_variable_set(:@host, nil) # Clear cached value

if RoadlioTag.host == 'my-firebase-app.firebaseapp.com'
  puts "  ✓ Custom host 'my-firebase-app.firebaseapp.com' detected from ENV"
else
  puts "  ✗ Expected 'my-firebase-app.firebaseapp.com', got '#{RoadlioTag.host}'"
end

# Restore original ENV
if original_env
  ENV['FIREBASE_AUTH_ORIGIN'] = original_env
  RoadlioTag.instance_variable_set(:@host, nil)
else
  ENV.delete('FIREBASE_AUTH_ORIGIN')
  RoadlioTag.instance_variable_set(:@host, nil)
end

puts

# Test 2: Check regex patterns adapt to host
puts "Test 2: Regex patterns adapt to host..."

# Test with default host
ENV.delete('FIREBASE_AUTH_ORIGIN')
RoadlioTag.instance_variable_set(:@host, nil)

regex = RoadlioTag.valid_url_regexp
if regex.to_s.include?('roadtrip-planen.de')
  puts "  ✓ Default regex includes 'roadtrip-planen.de'"
else
  puts "  ✗ Expected regex to include 'roadtrip-planen.de'"
end

# Test with custom host
ENV['FIREBASE_AUTH_ORIGIN'] = 'http://localhost:3000'
RoadlioTag.instance_variable_set(:@host, nil)

regex = RoadlioTag.valid_url_regexp
if regex.to_s.include?('localhost')
  puts "  ✓ Custom regex includes 'localhost'"
else
  puts "  ✗ Expected regex to include 'localhost'"
end

puts

# Test 3: Test URL validation with different hosts
puts "Test 3: URL validation with different hosts..."

# Test with default host
ENV.delete('FIREBASE_AUTH_ORIGIN')
RoadlioTag.instance_variable_set(:@host, nil)

valid_url = 'https://roadtrip-planen.de/reise-ansehen/abc123'
invalid_url = 'https://localhost:3000/reise-ansehen/abc123'

if valid_url.match?(RoadlioTag.valid_url_regexp)
  puts "  ✓ Default host: valid roadtrip-planen.de URL matches"
else
  puts "  ✗ Default host: valid URL should match"
end

if invalid_url.match?(RoadlioTag.valid_url_regexp)
  puts "  ✗ Default host: localhost URL should NOT match"
else
  puts "  ✓ Default host: localhost URL does not match (as expected)"
end

# Test with localhost host
ENV['FIREBASE_AUTH_ORIGIN'] = 'http://localhost:3000'
RoadlioTag.instance_variable_set(:@host, nil)

valid_url = 'https://localhost:3000/reise-ansehen/abc123'
invalid_url = 'https://roadtrip-planen.de/reise-ansehen/abc123'

if valid_url.match?(RoadlioTag.valid_url_regexp)
  puts "  ✓ Localhost host: valid localhost URL matches"
else
  puts "  ✗ Localhost host: valid URL should match"
end

if invalid_url.match?(RoadlioTag.valid_url_regexp)
  puts "  ✗ Localhost host: roadtrip-planen.de URL should NOT match"
else
  puts "  ✓ Localhost host: roadtrip-planen.de URL does not match (as expected)"
end

# Restore original ENV
if original_env
  ENV['FIREBASE_AUTH_ORIGIN'] = original_env
  RoadlioTag.instance_variable_set(:@host, nil)
else
  ENV.delete('FIREBASE_AUTH_ORIGIN')
  RoadlioTag.instance_variable_set(:@host, nil)
end

puts

# Test 4: Test Article#extract_roadlio_urls with different hosts
puts "Test 4: Article#extract_roadlio_urls with different hosts..."

# Create a mock article
class MockArticle
  attr_accessor :body_markdown
  
  def extract_roadlio_urls
    return [] unless body_markdown
    
    # Use the same regex as RoadlioTag (dynamic based on FIREBASE_AUTH_ORIGIN)
    roadlio_regex = RoadlioTag.valid_url_regexp
    
    # Find all matches
    body_markdown.scan(roadlio_regex).flatten.uniq
  end
end

# Test with default host
ENV.delete('FIREBASE_AUTH_ORIGIN')
RoadlioTag.instance_variable_set(:@host, nil)

article = MockArticle.new
article.body_markdown = "Check out: https://roadtrip-planen.de/reise-ansehen/abc123"
urls = article.extract_roadlio_urls

if urls == ['https://roadtrip-planen.de/reise-ansehen/abc123']
  puts "  ✓ Default host: roadtrip-planen.de URL extracted"
else
  puts "  ✗ Expected to extract roadtrip-planen.de URL, got #{urls.inspect}"
end

# Test with localhost host
ENV['FIREBASE_AUTH_ORIGIN'] = 'http://localhost:3000'
RoadlioTag.instance_variable_set(:@host, nil)

article = MockArticle.new
article.body_markdown = "Check out: https://localhost:3000/reise-ansehen/abc123"
urls = article.extract_roadlio_urls

if urls == ['https://localhost:3000/reise-ansehen/abc123']
  puts "  ✓ Localhost host: localhost URL extracted"
else
  puts "  ✗ Expected to extract localhost URL, got #{urls.inspect}"
end

# Restore original ENV
if original_env
  ENV['FIREBASE_AUTH_ORIGIN'] = original_env
  RoadlioTag.instance_variable_set(:@host, nil)
else
  ENV.delete('FIREBASE_AUTH_ORIGIN')
  RoadlioTag.instance_variable_set(:@host, nil)
end

puts
puts "=" * 80
puts "TEST COMPLETE"
puts "=" * 80
puts
puts "To use localhost for testing, set:"
puts "  ENV['FIREBASE_AUTH_ORIGIN'] = 'http://localhost:3000'"
puts
puts "Then roadlio URLs like 'https://localhost:3000/reise-ansehen/...' will be accepted"
