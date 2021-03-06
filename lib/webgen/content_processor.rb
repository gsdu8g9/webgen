# -*- encoding: utf-8 -*-

require 'webgen/extension_manager'
require 'webgen/error'

module Webgen

  # Namespace for all content processors.
  #
  # == About
  #
  # Content processors are used to process the content of paths, normally of paths in Webgen Page
  # Format. However, they can potentially process any type of content, even binary content.
  #
  # == Implementing a content processor
  #
  # A content processor only needs to respond to one method called +call+. This method is invoked
  # with a Webgen::Context object that provides the whole context (especially the content and the
  # node chain) and the method needs to return this object. During processing a content processor
  # normally changes the content of the context but it does not need to.
  #
  # This allows one to implement a content processor as a class with a class method called +call+.
  # Or as a Proc object.
  #
  # The content processor has to be registered so that webgen knows about it, see
  # ContentProcessor.register for more information.
  #
  # == Sample Content Processor
  #
  # The following sample content processor checks for a meta information +replace_key+ and replaces
  # strings of the form 'replace_key:path/to/node' with a link to the specified node if it is found.
  #
  # Note how the content node, the reference node and the destination node are used so that the
  # correct meta information is used, the node is correctly resolved and the correct relative link
  # is calculated respectively!
  #
  #   class Replacer
  #
  #     def self.call(context)
  #       if !context.content_node['replace_key'].to_s.empty?
  #         context.content.gsub!(/#{context.content_node['replace_key']}:([\w\/.]+)/ ) do |match|
  #           link_node = context.ref_node.resolve($1, context.content_node.lang)
  #           if link_node
  #             context.dest_node.link_to(link_node, context.content_node.lang)
  #           else
  #             match
  #           end
  #         end
  #       end
  #       context
  #     rescue Exception => e
  #       raise "Error while replacing special key: #{e.message}"
  #     end
  #
  #   end
  #
  #   website.ext.content_processor.register Replacer, :name => 'replacer'
  #
  class ContentProcessor

    include Webgen::ExtensionManager

    # Register a content processor.
    #
    # The parameter +klass+ can either be a String containing the name of a class/module (which has
    # to respond to :call) or an object that responds to :call. If the class is located under this
    # namespace, only the class name without the hierarchy part is needed, otherwise the full
    # class/module name including parent module/class names is needed.
    #
    # Instead of registering an object that responds to \#call, you can also provide a block that
    # has to take one parameter (the context object).
    #
    # === Options:
    #
    # [:name] The name for the content processor. If not set, it defaults to the snake-case version
    #         of the class name (without the hierarchy part). It should only contain letters.
    #
    # [:type] Defines which type of content the content processor can process. Can be set to either
    #         :text (the default) or :binary.
    #
    # [:ext_map] Defines a mapping of pre-processed file extension names to post-processed
    #            file extension names (e.g. {'sass' => 'css'}).
    #
    # === Examples:
    #
    #   content_processor.register('Kramdown')     # registers Webgen::ContentProcessor::Kramdown
    #
    #   content_processor.register('::Kramdown')   # registers Kramdown !!!
    #
    #   content_processor.register('MyModule::Doit', type: :binary)
    #
    #   content_processor.register('doit') do |context|
    #     context.content = 'Nothing left.'
    #   end
    #
    def register(klass, options={}, &block)
      name = do_register(klass, options, true, &block)
      ext_data(name).type = options[:type] || :text
      ext_data(name).extension_map = options[:ext_map] || {}
    end

    # Call the content processor object identified by the given name with the given context.
    def call(name, context)
      extension(name).call(context)
    rescue Webgen::Error => e
      e.path = context.dest_node if e.path.to_s.empty?
      e.location = "content_processor.#{name}" unless e.location
      raise
    rescue Exception => e
      raise Webgen::RenderError.new(e, "content_processor.#{name}", context.dest_node)
    end

    # Normalize the content processor pipeline.
    #
    # The pipeline parameter can be a String in the format 'a,b,c' or 'a, b, c' or an array '[a, b,
    # c]' with content processor names a, b and c.
    #
    # Raises an error if an unknown content processor is found.
    #
    # Returns an array with valid content processors.
    def normalize_pipeline(pipeline)
      pipeline = (pipeline.kind_of?(String) ? pipeline.split(/,\s*/) : pipeline.to_a)
      pipeline.each do |processor|
        raise Webgen::Error.new("Unknown content processor '#{processor}'") if !registered?(processor)
      end
      pipeline
    end

    # Return whether the content processor is processing binary data.
    def is_binary?(name)
      registered?(name) && ext_data(name).type == :binary
    end

    # Return the mapping of pre-processed file extension names to post-processed file extension
    # names for the given content processor or a combination of all mappings if +name+ is +nil+.
    #
    # An empty map is returned if the content processor is not registered.
    def extension_map(name = nil)
      if name.nil?
        @extension_map ||= registered_extensions.inject({}) {|hash, data| hash.update(data.last.extension_map)}
      elsif registered?(name)
        ext_data(name).extension_map
      else
        {}
      end
    end

    # Return the content processor name and the mapped extension of a pre-processed file extension
    # or +nil+ if the extension cannot be mapped.
    def map_extension(ext)
      registered_extensions.each do |name, data|
        mapped_ext = data.extension_map[ext]
        return [name, mapped_ext] if mapped_ext
      end
      nil
    end

  end

end
