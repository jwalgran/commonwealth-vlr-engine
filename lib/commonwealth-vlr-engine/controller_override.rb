module CommonwealthVlrEngine
  module ControllerOverride
    extend ActiveSupport::Concern

    included do

      # adds behavior for retrieving files for an object
      self.send(:include, CommonwealthVlrEngine::Finder)

      if self.respond_to? :search_params_logic
        search_params_logic.concat [:exclude_unwanted_models, :exclude_unpublished_items, :exclude_institutions, :exclude_volumes]
      end

      if self.blacklight_config.search_builder_class
        self.blacklight_config.search_builder_class.send(:include,
                                                         CommonwealthVlrEngine::CommonwealthSearchBuilder
        ) unless
            self.blacklight_config.search_builder_class.include?(
                CommonwealthVlrEngine::CommonwealthSearchBuilder
            )
      end

      before_filter :get_object_files, :only => [:show]
      before_filter :set_nav_context, :only => [:index]
      before_filter :mlt_search, :only => [:index]
      before_filter :add_institution_fields, :only => [:index, :facet]

      helper_method :has_volumes?

      # all the commonwealth-vlr-engine CatalogController config stuff goes here
      configure_blacklight do |config|

        #set default per-page
        config.default_per_page = 20

        #blacklight-gallery stuff
        config.view.gallery.default = true
        config.view.gallery.partials = [:index_header]
        config.view.gallery.icon_class = 'glyphicon-th-large'
        config.view.masonry.partials = [:index_header]
        config.view.slideshow.partials = [:index]

        # blacklight-maps stuff
        config.view.maps.geojson_field = 'subject_geojson_facet_ssim'
        config.view.maps.coordinates_field = 'subject_coordinates_geospatial'
        config.view.maps.placename_field = 'subject_geographic_ssim'
        config.view.maps.maxzoom = 13
        config.view.maps.show_initial_zoom = 9
        config.view.maps.facet_mode = 'geojson'

        # helper that returns thumbnail URLs
        config.index.thumbnail_method = :create_thumb_img_element

        # configuration for search results/index views
        config.index.partials = [:thumbnail, :index_header, :index]
        config.index.document_actions = nil # don't show bookmark control

        # solr field configuration for document/show views
        config.show.title_field = 'title_info_primary_tsi'
        config.show.display_type_field = 'active_fedora_model_suffix_ssi'

        # solr field for flagged/inappropriate content
        config.flagged_field = 'flagged_content_ssi'

        # advanced search facet limits
        config.advanced_search = {
            :qt => 'search',
            :form_solr_parameters => {
                'facet.field' => ['genre_basic_ssim', 'collection_name_ssim'],
                'facet.limit' => -1, # return all facet values
                'facet.sort' => 'index' # sort by byte order of values
            }
        }

        # collection name field
        config.collection_field = 'collection_name_ssim'
        # institution name field
        config.institution_field = 'institution_name_ssim'

        # book stuff
        config.ocr_search_field = 'ocr_tsiv'
        config.page_num_field = 'page_num_label_ssi'

        config.default_solr_params = {:qt => 'search', :rows => 20}

        # solr field configuration for search results/index views
        config.index.title_field = 'title_info_primary_tsi'
        config.index.display_type_field = 'active_fedora_model_suffix_ssi'

        # solr fields that will be treated as facets by the blacklight application
        config.add_facet_field 'subject_facet_ssim', :label => 'Topic', :limit => 8, :sort => 'count', :collapse => false
        config.add_facet_field 'subject_geographic_ssim', :label => 'Place', :limit => 8, :sort => 'count', :collapse => false
        config.add_facet_field 'date_facet_ssim', :label => 'Date', :limit => 8, :sort => 'index', :collapse => false
        config.add_facet_field 'genre_basic_ssim', :label => 'Format', :limit => 8, :sort => 'count', :helper_method => :render_format, :collapse => false
        config.add_facet_field 'collection_name_ssim', :label => 'Collection', :limit => 8, :sort => 'count', :collapse => false
        # link_to_facet fields (not in facets sidebar of search results)
        config.add_facet_field 'related_item_host_ssim', :label => 'Collection', :include_in_request => false # Collection (local)
        config.add_facet_field 'genre_specific_ssim', :label => 'Genre', :include_in_request => false
        config.add_facet_field 'related_item_series_ssim', :label => 'Series', :limit => 300, :sort => 'index', :include_in_request => false
        config.add_facet_field 'related_item_subseries_ssim', :label => 'Subseries', :include_in_request => false
        config.add_facet_field 'related_item_subsubseries_ssim', :label => 'Sub-subseries', :include_in_request => false
        config.add_facet_field 'institution_name_ssim', :label => 'Institution', :include_in_request => false
        config.add_facet_field 'name_facet_ssim', :label => 'Name', :include_in_request => false
        # facet for blacklight-maps catalog#index map view
        # have to use '-2' to get all values
        # because Blacklight::RequestBuilders#solr_facet_params adds '+1' to value
        config.add_facet_field 'subject_geojson_facet_ssim', :limit => -2, :label => 'Coordinates', :show => false

        # solr fields to be displayed in the index (search results) view
        config.add_index_field 'genre_basic_ssim', :label => 'Format', :helper_method => :render_format_index
        config.add_index_field 'collection_name_ssim', :label => 'Collection', :helper_method => :index_collection_link
        config.add_index_field 'date_start_tsim', :label => 'Date', :helper_method => :index_date_value

        # "fielded" search configuration. Used by pulldown among other places.
        config.add_search_field('all_fields') do |field|
          field.label = 'All Fields'
          field.solr_parameters = { :'spellcheck.dictionary' => 'default' }
        end

        config.add_search_field('title') do |field|
          field.solr_parameters = { :'spellcheck.dictionary' => 'default' }
          field.solr_local_parameters = {
              :qf => '$title_qf',
              :pf => '$title_pf'
          }
        end

        config.add_search_field('subject') do |field|
          field.solr_parameters = { :'spellcheck.dictionary' => 'default' }
          field.qt = 'search'
          field.solr_local_parameters = {
              :qf => '$subject_qf',
              :pf => '$subject_pf'
          }
        end

        config.add_search_field('place') do |field|
          field.solr_parameters = { :'spellcheck.dictionary' => 'default' }
          field.solr_local_parameters = {
              :qf => '$place_qf',
              :pf => '$place_pf'
          }
        end

        config.add_search_field('creator') do |field|
          field.solr_parameters = { :'spellcheck.dictionary' => 'default' }
          field.solr_local_parameters = {
              :qf => '$author_qf',
              :pf => '$author_pf'
          }
        end

        # "sort results by" select (pulldown)
        config.add_sort_field 'score desc, title_info_primary_ssort asc', :label => 'relevance'
        config.add_sort_field 'title_info_primary_ssort asc, date_start_dtsi asc', :label => 'title'
        config.add_sort_field 'date_start_dtsi asc, title_info_primary_ssort asc', :label => 'date (asc)'
        config.add_sort_field 'date_start_dtsi desc, title_info_primary_ssort asc', :label => 'date (desc)'

      end

      # displays the MODS XML record. copied from blacklight-marc 'librarian_view'
      # for some reason won't work if not in the 'included' block
      def metadata_view
        @response, @document = fetch(params[:id])

        respond_to do |format|
          format.html
          format.js { render :layout => false }
        end
      end

      # modify facet settings for Collections#show and Institutions#show
      def relation_base_blacklight_config
        # don't show collection facet
        blacklight_config.facet_fields['collection_name_ssim'].show = false
        blacklight_config.facet_fields['collection_name_ssim'].if = false
        # collapse remaining facets
        blacklight_config.facet_fields['subject_facet_ssim'].collapse = true
        blacklight_config.facet_fields['subject_geographic_ssim'].collapse = true
        blacklight_config.facet_fields['date_facet_ssim'].collapse = true
        blacklight_config.facet_fields['genre_basic_ssim'].collapse = true
      end

    end

    # displays values and pagination links for Format field
    def formats_facet
      @nav_li_active = 'explore'

      @facet = blacklight_config.facet_fields['genre_basic_ssim']
      @response = get_facet_field_response(@facet.key, params)
      @display_facet = @response.aggregations[@facet.key]

      @pagination = facet_paginator(@facet, @display_facet)

      render :facet
    end

    # if this is 'more like this' search, solr id = params[:mlt_id]
    def mlt_search
      if params[:mlt_id]
        CatalogController.search_params_logic += [:set_solr_id_for_mlt] unless CatalogController.search_params_logic.include? :set_solr_id_for_mlt
      end
    end

    # TODO: refactor how views access files/volumes/etc.
    def get_object_files
      @object_files = get_files(params[:id])
    end

    def set_nav_context
      @nav_li_active = 'search'
    end

    # add institutions if configured
    def add_institution_fields
      if t('blacklight.home.browse.institutions.enabled')
        blacklight_config.add_facet_field 'physical_location_ssim', :label => 'Institution', :limit => 8, :sort => 'count', :collapse => false
        blacklight_config.add_index_field 'institution_name_ssim', :label => 'Institution', :helper_method => :index_institution_link
      end
    end

    # TODO: refactor how views access files/volumes/etc.
    # returns the child volumes for Book objects (if they exist)
    # needs to be in this module because CommonwealthVlrEngine::Finder methods aren't accessible in helpers/views
    def has_volumes?(document)
      case document[blacklight_config.show.display_type_field.to_sym]
        when 'Book'
          volumes = get_volume_objects(document.id)
        else
          volumes = nil
      end
      volumes.presence
    end

  end

end