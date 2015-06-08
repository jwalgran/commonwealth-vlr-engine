module CommonwealthVlrEngine
  module CatalogHelper
    include Blacklight::CatalogHelperBehavior

    # return the image url for the collection gallery view document
    # size = pixel length of square IIIF-created image
    def collection_gallery_url document, size
      exemplary_image_pid = document[:exemplary_image_ssi]
      if exemplary_image_pid
        if exemplary_image_pid.match(/oai/)
          datastream_disseminator_url(exemplary_image_pid,'thumbnail300')
        else
          iiif_square_img_path(exemplary_image_pid, size)
        end
      else
        collection_icon_path
      end
    end

    def collection_icon_path
      'commonwealth-vlr-engine/dc_collection-icon.png'
    end

    def create_download_links(files_hash, link_class)
      file_types = [files_hash[:documents], files_hash[:audio], files_hash[:generic]]
      download_links = []
      file_types.each do |file_type|
        file_type.each do |file|
          object_profile_json = JSON.parse(file['object_profile_ssm'].first)
          file_name_ext = object_profile_json["objLabel"].split('.')
          download_links << link_to(file_name_ext[0],
                                    download_path(file['id'],:datastream_id => 'productionMaster')                                  ,
                                    :target => '_blank',
                                    :class => link_class) + content_tag(:span, '(' + file_name_ext[1].upcase + ', ' + number_to_human_size(object_profile_json["datastreams"]["productionMaster"]["dsSize"]) + ')', :class => 'download_info')
        end
      end
      download_links
    end

    def create_thumb_img_element(document, img_class=[])
      image_classes = img_class.class == Array ? img_class.join(' ') : ''
      image_tag(thumbnail_url(document),
                :alt => document[blacklight_config.index.title_field.to_sym],
                :class => image_classes)
    end

    def extra_body_classes
      @extra_body_classes ||= ['blacklight-' + controller.controller_name, 'blacklight-' + [controller.controller_name, controller.action_name].join('-')]
      # if this is the home page
      if controller.controller_name == 'pages' && controller.action_name =='home'
        @extra_body_classes.push('blacklight-home')
      else
        @extra_body_classes
      end
    end

    def has_downloadable_files? files_hash
      files_hash[:documents].present? ||
          files_hash[:audio].present? ||
          files_hash[:generic].present?
    end

    def has_image_files? files_hash
      image_file_pids = nil
      unless files_hash[:images].empty?
        image_file_pids = []
        files_hash[:images].each do |image_file|
          image_file_pids << image_file['id']
        end
      end
      image_file_pids
    end

    # render collection name as a link in catalog#index list view
    def index_collection_link options={}
      link_to(options[:value].first,
              collection_path(:id => options[:document][:collection_pid_ssm].first))
    end


    # render the date in the catalog#index list view
    def index_date_value options={}
      date_end = options[:document][:date_end_tsim] ? options[:document][:date_end_tsim].first : nil
      date_start_qualifier = options[:document][:date_start_qualifier_ssm] ? options[:document][:date_start_qualifier_ssm].first : nil
      render_mods_dates(options[:value].first, date_end, date_start_qualifier)
    end

    # render institution name as a link in catalog#index list view
    def index_institution_link options={}
      link_to(options[:value].first,
              institution_path(:id => options[:document][:institution_pid_ssi]))
    end

    # render the collection/institution icon if necessary
    def index_relation_base_icon document
      display_type = document[blacklight_config.view_config(document_index_view_type).display_type_field].downcase
      if controller.controller_name == 'catalog' && (display_type == 'collection' || display_type == 'institution')
        image_tag("commonwealth-vlr-engine/dc_#{display_type}-icon.png", alt: "#{display_type} icon", class: "index-title-icon #{display_type}-icon")
      else
        ''
      end
    end

    # return the URL of an image to display in the catalog#index slideshow view
    def index_slideshow_img_url document
      if document[:exemplary_image_ssi] && !document[blacklight_config.flagged_field.to_sym]
        if document[blacklight_config.index.display_type_field.to_sym] == 'OAIObject' || document[:exemplary_image_ssi].match(/oai/)
          thumbnail_url(document)
        else
          iiif_image_url(document[:exemplary_image_ssi], {:size => ',500'})
        end
      elsif document[:type_of_resource_ssim]
        render_object_icon_path(document[:type_of_resource_ssim].first)
      elsif document[blacklight_config.index.display_type_field.to_sym] == 'Collection'
        collection_icon_path
      elsif document[blacklight_config.index.display_type_field.to_sym] == 'Institution'
        institution_icon_path
      else
        render_object_icon_path(nil)
      end
    end

    # determine the 'truncate' length based on catalog#index view type
    def index_title_length
      case params[:view]
        when 'list'
          170
        when 'masonry'
          89
        else
          130
      end
    end

    def institution_icon_path
      'commonwealth-vlr-engine/dc_institution-icon.png'
    end

    def normalize_date(date)
      if date.length == 10
        Date.parse(date).strftime('%B %-d, %Y')
      elsif date.length == 7
        Date.parse(date + '-01').strftime('%B %Y')
      else
        date
      end
    end

    # insert an icon and link to CC licenses
    def render_cc_license(terms)
      terms_code = terms.match(/\s[BYNCDSA-]{2,}/).to_s.strip.downcase
      link_to(image_tag('//i.creativecommons.org/l/' + terms_code + '/3.0/80x15.png',
                        :alt => 'CC ' + terms_code.upcase + ' icon',
                        :class => 'cc_license_icon'),
              'http://creativecommons.org/licenses/' + terms_code + '/3.0',
              :rel => 'license',
              :id => 'cc_license_link',
              :target => '_blank')
    end

    # render metadata for <mods:hierarchicalGeographic> subjects from GeoJSON
    def render_hiergo_subject(geojson_feature, separator, separator_class=nil)
      output_array = []
      hiergeo_hash = JSON.parse(geojson_feature).symbolize_keys[:properties]
      hiergeo_hash.each_key do |k|
        if k == 'country' && hiergeo_hash[k] == 'United States'
          # display 'United States' only if no other values
          output_array << link_to_facet(hiergeo_hash[k], 'subject_geographic_ssim') if hiergeo_hash.length == 1
        elsif k == 'county'
          output_array << link_to_facet("#{hiergeo_hash[k]} (county)", 'subject_geographic_ssim')
        elsif k == 'island' || k == 'area' || k == 'province' || k == 'territory' || k == 'region'
          output_array << link_to_facet(hiergeo_hash[k], 'subject_geographic_ssim') + " (#{k.to_s})"
        elsif k == 'other'
          place_type = hiergeo_hash[k].scan(/\([a-z\s]*\)/).last
          place_name = hiergeo_hash[k].gsub(/#{place_type}/,'').gsub(/\s\(\)\z/,'')
          output_array << link_to_facet(place_name, 'subject_geographic_ssim') + " #{place_type.to_s}"
        else
          output_array << link_to_facet(hiergeo_hash[k], 'subject_geographic_ssim')
        end
      end
      output_array.join(content_tag(:span, separator, :class => separator_class)).html_safe
    end

    def render_item_breadcrumb(document)
      if document[:collection_pid_ssm]
        connector = content_tag(:span, '',
                                :class => 'glyphicon glyphicon-arrow-right item-breadcrumb-separator')
        coll_link = link_to(document[blacklight_config.collection_field.to_sym].first,
                            collection_path(:id => document[:collection_pid_ssm].first),
                            :class => 'collection_breadcrumb')
        coll_link
      end
    end

    # render the 'more like this' search link if doc has subjects
    def render_mlt_search_link(document)
      if document[:subject_facet_ssim] || document[:subject_geo_city_ssim]
        content_tag :div, :id => 'more_mlt_link_wrapper' do
          link_to t('blacklight.more_like_this.more_mlt_link'),
                  catalog_index_path(:mlt_id => document.id,
                                     :qt => 'mlt'),
                  :id => 'more_mlt_link'
        end
      end
    end

    def render_mods_dates (date_start, date_end = nil, date_qualifier = nil, date_type = nil)
      prefix = ''
      suffix = ''
      date_start_suffix = ''
      if date_qualifier && date_qualifier != 'nil'
        prefix = date_qualifier == 'approximate' ? '[ca. ' : '['
        suffix = date_qualifier == 'questionable' ? '?]' : ']'
      end
      prefix << 'c' if date_type == 'copyrightDate'
      if date_end && date_end != 'nil'
        date_start_suffix = '?' if date_qualifier == 'questionable'
        prefix + normalize_date(date_start) + date_start_suffix + t('blacklight.metadata_display.date_range_connector') + normalize_date(date_end) + suffix
      else
        prefix + normalize_date(date_start) + suffix
      end
    end

    def render_mods_xml_record(document_id)
      mods_xml_file_path = datastream_disseminator_url(document_id, 'descMetadata')
      mods_response = Typhoeus::Request.get(mods_xml_file_path)
      mods_xml_text = REXML::Document.new(mods_response.body)
    end

    # create a list of names and roles to be displayed
    def setup_names_roles(document)
      names = []
      roles = []
      multi_role_indices = []
      name_fields = [document[:name_personal_tsim], document[:name_corporate_tsim], document[:name_generic_tsim]]
      role_fields = [document[:name_personal_role_tsim], document[:name_corporate_role_tsim], document[:name_generic_role_tsim]]
      name_fields.each_with_index do |name_field,name_field_index|
        if name_field
          0.upto name_field.length-1 do |index|
            names << name_field[index]
            if role_fields[name_field_index] && role_fields[name_field_index][index]
              roles << role_fields[name_field_index][index].strip
            else
              roles << 'Creator'
            end
          end
        end
      end
      roles.each_with_index do |role,index|
        if /[\|]{2}/.match(role)
          multi_roles = role.split('||')
          multi_role_name = names[index]
          multi_role_indices << index
          multi_roles.each { |multi_role| roles << multi_role }
          0.upto multi_roles.length-1 do
            names << multi_role_name
          end
        end
      end
      unless multi_role_indices.empty?
        multi_role_indices.reverse.each do |index|
          names.delete_at(index)
          roles.delete_at(index)
        end
      end
      return names,roles
    end

    def should_autofocus_on_search_box?
      (controller.is_a? Blacklight::Catalog and
          action_name == "index" and
          params[:q].to_s.empty? and
          params[:f].to_s.empty?) or
          (controller.is_a? PagesController and action_name == 'home')
    end

    # LOCAL OVERRIDE: don't want to pull thumbnail url from Solr
    def thumbnail_url document
      if document[:exemplary_image_ssi] && (!document[blacklight_config.flagged_field.to_sym] || controller.action_name == 'show')
        datastream_disseminator_url(document[:exemplary_image_ssi], 'thumbnail300')
      elsif document[:type_of_resource_ssim]
        render_object_icon_path(document[:type_of_resource_ssim].first)
      elsif document[blacklight_config.index.display_type_field.to_sym] == 'Collection'
        collection_icon_path
      elsif document[blacklight_config.index.display_type_field.to_sym] == 'Institution'
        institution_icon_path
      else
        render_object_icon_path(nil)
      end
    end

  end
end