module Api
  module V1
    class GeosearchController < ApiController
      before_action :authenticate_user!, only: %i[create_or_update destroy]
      
      # GET /api/v1/geosearch/nearby
      # Search for articles near a point
      # @param [Float] lat Latitude
      # @param [Float] lon Longitude
      # @param [Float] radius_km Search radius in kilometers (default: 10)
      # @param [Integer] limit Maximum results (default: 20)
      def nearby
        lat = params[:lat]&.to_f
        lon = params[:lon]&.to_f
        radius_km = params[:radius_km]&.to_f || GeosearchService::DEFAULT_SEARCH_RADIUS_KM
        limit = params[:limit]&.to_i || GeosearchService::DEFAULT_SEARCH_LIMIT
        
        unless lat && lon
          return json_response({ error: 'Both lat and lon parameters are required' }, :bad_request)
        end
        
        service = GeosearchService.new
        results = service.search_near_point([lon, lat], radius_meters: radius_km * 1000, limit: limit)
        
        json_response({ 
          results: results.map { |r| serialize_result(r) },
          count: results.length,
          metadata: { 
            center: { lat: lat, lon: lon },
            radius_km: radius_km
          }
        })
      end
      
      # GET /api/v1/geosearch/bounds
      # Search for articles within a bounding box
      # @param [Float] min_lat Minimum latitude
      # @param [Float] min_lon Minimum longitude
      # @param [Float] max_lat Maximum latitude
      # @param [Float] max_lon Maximum longitude
      # @param [Integer] limit Maximum results (default: 20)
      def within_bounds
        min_lat = params[:min_lat]&.to_f
        min_lon = params[:min_lon]&.to_f
        max_lat = params[:max_lat]&.to_f
        max_lon = params[:max_lon]&.to_f
        limit = params[:limit]&.to_i || GeosearchService::DEFAULT_SEARCH_LIMIT
        
        unless min_lat && min_lon && max_lat && max_lon
          return json_response({ error: 'All bounds parameters (min_lat, min_lon, max_lat, max_lon) are required' }, :bad_request)
        end
        
        bounds = {
          min_lon: min_lon,
          min_lat: min_lat,
          max_lon: max_lon,
          max_lat: max_lat
        }
        
        service = GeosearchService.new
        articles = service.search_within_bounds(bounds, limit: limit)
        
        json_response({ 
          results: articles.map { |a| serialize_article(a) },
          count: articles.length,
          metadata: { bounds: bounds }
        })
      end
      
      # GET /api/v1/geosearch/count
      # Count articles within a bounding box or radius
      # @param [Float] lat Latitude (for radius search)
      # @param [Float] lon Longitude (for radius search)
      # @param [Float] radius_km Search radius in kilometers
      # @param [Float] min_lat Minimum latitude (for bounds search)
      # @param [Float] min_lon Minimum longitude (for bounds search)
      # @param [Float] max_lat Maximum latitude (for bounds search)
      # @param [Float] max_lon Maximum longitude (for bounds search)
      def count
        service = GeosearchService.new
        
        if params[:lat] && params[:lon]
          # Radius search
          lat = params[:lat].to_f
          lon = params[:lon].to_f
          radius_km = params[:radius_km]&.to_f || GeosearchService::DEFAULT_SEARCH_RADIUS_KM
          
          count = service.count_within_radius([lon, lat], radius_km: radius_km)
          
          json_response({ 
            count: count,
            metadata: { 
              type: 'radius',
              center: { lat: lat, lon: lon },
              radius_km: radius_km
            }
          })
        elsif params[:min_lat] && params[:min_lon] && params[:max_lat] && params[:max_lon]
          # Bounds search
          bounds = {
            min_lon: params[:min_lon].to_f,
            min_lat: params[:min_lat].to_f,
            max_lon: params[:max_lon].to_f,
            max_lat: params[:max_lat].to_f
          }
          
          count = service.count_within_bounds(bounds)
          
          json_response({ 
            count: count,
            metadata: { 
              type: 'bounds',
              bounds: bounds
            }
          })
        else
          json_response({ error: 'Either radius (lat, lon, radius_km) or bounds (min_lat, min_lon, max_lat, max_lon) parameters are required' }, :bad_request)
        end
      end
      
      # GET /api/articles/:id/geodata
      # Get geodata for a specific article
      def show
        article = Article.find_by(id: params[:article_id])
        
        unless article
          return json_response({ error: 'Article not found' }, :not_found)
        end
        
        geodatum = article.article_geodatum
        
        if geodatum
          json_response({ 
            article_id: article.id,
            geojson: geodatum.geojson_data,
            geometry_type: geodatum.geometry_type,
            bounds: {
              min_lon: geodatum.bounds_min_lon,
              min_lat: geodatum.bounds_min_lat,
              max_lon: geodatum.bounds_max_lon,
              max_lat: geodatum.bounds_max_lat
            },
            source_type: geodatum.source_type,
            source_metadata: geodatum.source_metadata,
            created_at: geodatum.created_at,
            updated_at: geodatum.updated_at
          })
        else
          json_response({ 
            article_id: article.id,
            geojson: nil,
            message: 'No geodata for this article'
          })
        end
      end
      
      # POST /api/articles/:id/geodata
      # Create or update geodata for an article
      def create_or_update
        article = Article.find_by(id: params[:article_id])
        
        unless article
          return json_response({ error: 'Article not found' }, :not_found)
        end
        
        unless current_user && (current_user == article.user || current_user.moderator?)
          return json_response({ error: 'Not authorized to edit this article' }, :forbidden)
        end
        
        geojson_data = params[:geojson] || params[:geojson_data]
        
        unless geojson_data
          return json_response({ error: 'geojson parameter is required' }, :bad_request)
        end
        
        begin
          # Parse JSON if it's a string
          geojson_data = JSON.parse(geojson_data) if geojson_data.is_a?(String)
          
          service = GeodataService.new(article, geojson_data: geojson_data, endpoint_url: params[:endpoint_url])
          geodatum = service.create_or_update_geodata(
            source_type: params[:source_type] || 'manual_entry',
            source_metadata: params[:source_metadata]
          )
          
          json_response({ 
            message: 'Geodata saved successfully',
            geodatum: {
              id: geodatum.id,
              geometry_type: geodatum.geometry_type,
              created_at: geodatum.created_at,
              updated_at: geodatum.updated_at
            }
          }, :created)
        rescue GeodataService::GeodataError => e
          json_response({ error: e.message }, :unprocessable_entity)
        end
      end
      
      # DELETE /api/articles/:id/geodata
      # Remove geodata from an article
      def destroy
        article = Article.find_by(id: params[:article_id])
        
        unless article
          return json_response({ error: 'Article not found' }, :not_found)
        end
        
        unless current_user && (current_user == article.user || current_user.moderator?)
          return json_response({ error: 'Not authorized to delete this geodata' }, :forbidden)
        end
        
        service = GeodataService.new(article)
        service.remove_geodata
        
        json_response({ message: 'Geodata removed successfully' })
      end
      
      private

      def json_response(payload, status = :ok)
        render json: payload, status: status
      end
      
      def serialize_result(result)
        {
          article: serialize_article(result.article),
          distance_meters: result.distance_meters,
          distance_km: result.distance_km.round(2)
        }
      end
      
      def serialize_article(article)
        {
          id: article.id,
          title: article.title,
          slug: article.slug,
          url: article.url,
          published_at: article.published_at,
          main_image: article.main_image,
          description: article.description,
          body_markdown: article.body_markdown,
          user: {
            id: article.user_id,
            username: article.user.username,
            name: article.user.name,
            profile_image: article.user.profile_image_url
          }
        }
      end
    end
  end
end
