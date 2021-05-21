module Plivo
  module XML
    class Element
      class << self
        attr_accessor :valid_attributes, :nestables
      end
      @nestables = []
      @valid_attributes = []
      SSML_TAGS=%w[Break Emphasis Lang P Phoneme Prosody S SayAs Sub W]

      attr_accessor :node, :name

      def hyphenate(pascal_cased_word)
        pascal_cased_word.to_s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1-\2').
          gsub(/([a-z\d])([A-Z])/,'\1-\2').
          downcase
      end

      def initialize(body = nil, attributes = {}, nestables=self.class.nestables)
        @name = self.class.name.split('::')[2]
        @body = body
        tagname = @name
        if SSML_TAGS.include?(@name)
          tagname = hyphenate(@name)
        end
        @node = REXML::Element.new tagname
        attributes.each do |k, v|
          if self.class.valid_attributes.include?(k.to_s)
            @node.attributes[k.to_s] = convert_value(v)
          else
            raise PlivoXMLError, "invalid attribute #{k} for #{@name}"
          end
        end
        @nestables = nestables
        @node.text = @body if @body

        # Allow for nested "nestable" elements using a code block
        # ie
        # Plivo::XML::Response.new do |r|
        #   r.Dial do |n|
        #     n.Number '+15557779999'
        #   end
        # end
        yield(self) if block_given?
      end

      def add_attribute(attribute, value)
        @node.add_attribute(attribute, value)
      end

      def method_missing(method, *args, &block)
        # Handle the addElement methods
        method = Regexp.last_match(1).to_sym if method.to_s =~ /^add(.*)/
        # Add the element
        begin
          add(Plivo::XML.const_get(method).new(*args, &block))
        rescue StandardError => e
          raise PlivoXMLError, e.message
        end
      end

      def convert_value(v)
        case v
        when true
          'true'
        when false
          'false'
        when nil
          'none'
        when 'get'
          'GET'
        when 'post'
          'POST'
        else
          v
        end
      end

      def add(element)
        raise PlivoXMLError, 'invalid element' unless element
        if @nestables.include?(element.name)
          @node.elements << element.node
          element
        else
          raise PlivoXMLError, "#{element.name} not nestable in #{@name}"
        end
      end

      def to_xml
        @node.to_s
      end

      def to_s
        @node.to_s
      end
    end
  end
end
