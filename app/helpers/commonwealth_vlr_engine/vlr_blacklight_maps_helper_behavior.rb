module CommonwealthVlrEngine
  module VlrBlacklightMapsHelperBehavior
    include Blacklight::BlacklightMapsHelperBehavior

    # OVERRIDE: convert state abbreviations, deal with complex locations, etc.
    # create a link to a location name facet value
    def link_to_placename_field field_value, field, displayvalue = nil, catalogpath = nil
      search_path = catalogpath || 'catalog_index_path'
      new_params = params
      new_params[:view] = default_document_index_view_type
      field_values = field_value.split(', ')
      if field_values.last.match(/[\.\)]/) # Mass.)
        field_values = [field_values.join(', ')]
      end
      if field_values.length > 2
        new_field_values = []
        new_field_values[0] = field_value.split(/[,][ \w]*\z/).first
        new_field_values[1] = field_values.last
        field_values = new_field_values
      end
      if field_values.length == 2 && field_values.last.length == 2
        state_name = Madison.get_name(field_values.last)
        field_values[field_values.length-1] = state_name if state_name
      end
      field_values.each do |val|
        place = val.match(/\(county\)/) ? val : val.gsub(/\s\([a-z]*\)\z/,'')
        new_params = add_facet_params(field, place, new_params) unless params[:f] && params[:f][field] && params[:f][field].include?(place)
        new_params[:view] = default_document_index_view_type
      end
      link_to(displayvalue.presence || field_value,
              self.send(search_path,new_params.except(:id, :spatial_search_type, :coordinates)))
    end

    # OVERRIDE: use a static file for catalog#map so page loads faster
    # render the map for #index and #map views
    def render_index_map
      static_geojson_file_loc = "#{Rails.root.to_s}/#{GEOJSON_STATIC_FILE['filepath']}"
      if Rails.env.to_s == 'production' && params[:action] == 'map' && File::exists?(static_geojson_file_loc)
        geojson_for_map = File.open(static_geojson_file_loc).first
      else
        geojson_for_map = serialize_geojson(map_facet_values)
      end
      render :partial => 'catalog/index_map',
             :locals => {:geojson_features => geojson_for_map}
    end


    # OVERRIDE: allow controller.action name to be passed, allow @controller
    # pass the document or facet values to BlacklightMaps::GeojsonExport
    def serialize_geojson(documents, action_name=nil, options={})
      action = action_name || controller.action_name
      cntrllr = @controller || controller
      export = BlacklightMaps::GeojsonExport.new(cntrllr, action, documents, options)
      export.to_geojson
    end

  end

end