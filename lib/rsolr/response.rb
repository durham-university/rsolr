module RSolr::Response

  def self.included(base)
    unless base < Hash
      raise ArgumentError, "RSolr::Response expects to included only in (sub)classes of Hash; got included in '#{base}' instead."
    end
    base.send(:attr_reader, :request, :response)
  end

  def initialize_rsolr_response(request, response, result)
    @request = request
    @response = response
    self.merge!(result)
    if self["response"] && self["response"]["docs"].is_a?(::Array)
      docs = PaginatedDocSet.new(self["response"]["docs"])
      docs.per_page = (request[:pagination] || {})[:per_page] || request[:params]["rows"] || request[:params][:rows]
      docs.solr_start = request[:params]["start"] || request[:params][:start]
      docs.solr_total = self["response"]["numFound"].to_s.to_i
      docs.pagination_offset = (request[:pagination] || {})[:offset]
      docs.pagination_limit = (request[:pagination] || {})[:limit]
      self["response"]["docs"] = docs
    end
  end

  def with_indifferent_access
    if defined?(::RSolr::HashWithIndifferentAccessWithResponse)
      ::RSolr::HashWithIndifferentAccessWithResponse.new(request, response, self)
    else
      if defined?(ActiveSupport::HashWithIndifferentAccess)
        RSolr.const_set("HashWithIndifferentAccessWithResponse", Class.new(ActiveSupport::HashWithIndifferentAccess))
        RSolr::HashWithIndifferentAccessWithResponse.class_eval <<-eos
          include RSolr::Response
          def initialize(request, response, result)
            super()
            initialize_rsolr_response(request, response, result)
          end
        eos
        ::RSolr::HashWithIndifferentAccessWithResponse.new(request, response, self)
      else
        raise RuntimeError, "HashWithIndifferentAccess is not currently defined"
      end
    end
  end

  # A response module which gets mixed into the solr ["response"]["docs"] array.
  class PaginatedDocSet < ::Array

    attr_accessor :solr_start, :per_page, :solr_total, :pagination_offset, :pagination_limit
    
    # Returns start row of current page. This is Solr start row possibly offset
    # by the offset param.
    def page_start
      pagination_offset.nil? ? solr_start : solr_start - pagination_offset
    end
    
    # Returns total number of rows for paging. This is total number of rows
    # reported by Solr and limited by possible offset and limit params.
    def page_total
      offset_total = pagination_offset.nil? ? solr_total : solr_total - pagination_offset
      pagination_limit.nil? ? offset_total : [offset_total, pagination_limit].min
    end

    if not (Object.const_defined?("RUBY_ENGINE") and Object::RUBY_ENGINE=='rbx')
      alias_method(:start,:page_start)
      alias_method(:total,:page_total)
    end

    # Returns the current page calculated from per_page and page_start
    def current_page
      return 1 if page_start < 1
      per_page_normalized = per_page < 1 ? 1 : per_page
      @current_page ||= (page_start / per_page_normalized).ceil + 1
    end

    # Calcuates the total pages from page_total and per_page
    def total_pages
      @total_pages ||= per_page > 0 ? (page_total / per_page.to_f).ceil : 1
    end

    # returns the previous page number or 1
    def previous_page
      @previous_page ||= (current_page > 1) ? current_page - 1 : 1
    end

    # returns the next page number or the last
    def next_page
      @next_page ||= (current_page == total_pages) ? total_pages : current_page+1
    end

    def has_next?
      current_page < total_pages
    end

    def has_previous?
      current_page > 1
    end

  end

end

class RSolr::HashWithResponse < Hash
  include RSolr::Response

  def initialize(request, response, result)
    super()
    initialize_rsolr_response(request, response, result || {})
  end
end
