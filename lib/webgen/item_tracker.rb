# -*- encoding: utf-8 -*-

require 'set'
require 'webgen/common'

module Webgen

  # Namespace for all item trackers.
  #
  # == About this class
  #
  # This extension manager class is used to track various "items". Such items can be added as a
  # dependency to a node and later be checked if they have changed. This allows webgen to
  # conditionally render a node.
  #
  # An item can basically be anything, there only has to be an item tracker extension that knows how
  # to handle it. Each item tracker extension is uniquely identified by its name (e.g.
  # :+node_content+, :+node_meta_info+, ...).
  #
  # == Implementing an item tracker.
  #
  # An item tracker extension class must respond to the following four methods:
  #
  # [<tt>initialize(website)</tt>]
  #   Initializes the extension and provides the website object which can be used to resolve the
  #   item ID to the referenced item or item data itself.
  #
  # [<tt>item_id(*item)</tt>]
  #   Return the unique ID for the given item. The returned ID has to be unique for this item
  #   tracker extension
  #
  # [<tt>item_data(*item)</tt>]
  #   Return the data for the item so that it can be correctly checked later if it has changed.
  #
  # [<tt>changed?(item_id, old_data)</tt>]
  #   Return +true+ if the item identified by its unique ID has changed. The parameter +old_data+
  #   contains the last known data of the item.
  #
  # The parameter +item+ for the methods +item_id+ and +item_data+ contains the information needed
  # to identify the item and is depdendent on the specific item tracker extension class. Therefore
  # you need to look at the documentation for an item tracker extension to see what it expects as
  # the item.
  #
  # Since these methods are invoked multiple times for different items, these methods should have no
  # side effects.
  #
  # == Sample item tracker
  #
  # The following sample item tracker tracks changes in configuration values. It needs the
  # configuration option name as item.
  #
  #   class ConfigTracker
  #
  #     def initialize(website)
  #       @website = website
  #     end
  #
  #     def item_id(config_key)
  #       config_key
  #     end
  #
  #     def item_data(config_key)
  #       @website.configuration[config_key]
  #     end
  #
  #     def changed?(config_key, old_val)
  #       @website.configuration[config_key] != old_val
  #     end
  #
  #   end
  #
  #   website.ext.item_tracker.register '::ConfigTracker', name: :config
  #
  class ItemTracker

    include Webgen::Common::ExtensionManager
    extend ClassMethods

    def initialize # :nodoc:
      super
      @instances = {}
      @node_dependencies = Hash.new {|h,k| h[k] = Set.new}
      @item_data = {}
      @cached = {:node_dependencies => {}, :item_data => {}}
    end

    def website=(ws) # :nodoc:
      if !website.nil?
        website.blackboard.remove_listener(:website_initialized, self)
        website.blackboard.remove_listener(:website_generated, self)
      end
      super
      website.blackboard.add_listener(:website_initialized, self) do
        @cached = website.cache[:item_tracker_data] || @cached
      end
      website.blackboard.add_listener(:website_generated, self) do
        website.cache[:item_tracker_data] = {
          :node_dependencies => @cached[:node_dependencies].merge(@node_dependencies),
          :item_data => @cached[:item_data].merge(@item_data)
        }
      end
    end

    # Register an item tracker. The parameter +klass+ has to contain the name of the item tracker
    # class. If the class is located under this namespace, only the class name without the hierarchy
    # part is needed, otherwise the full class name including parent module/class names is needed.
    #
    # All other parameters can be set through the options hash if the default values aren't
    # sufficient.
    #
    # === Options:
    #
    # [:name] The name for the item tracker class. If not set, it defaults to the snake-case version
    #         (i.e. FileSystem → file_system) of the class name (without the hierarchy part). It
    #         should only contain letters.
    #
    # === Examples:
    #
    #   item_tracker.register('Node')   # registers Webgen::ItemTracker::Node
    #
    #   item_tracker.register('::Node') # registers Node !!!
    #
    #   item_tracker.register('MyModule::Doit', name: 'infos')
    #
    def register(klass, options={}, &block)
      do_register(klass, options, [], false, &block)
    end

    # Add the given item that is handled by the item tracker extension +name+ as a dependency to the
    # node.
    def add(node, name, *item)
      uid = unique_id(name, item)
      @node_dependencies[node.alcn] << uid
      @item_data[uid] ||= item_tracker(name).item_data(*item)
    end

    # Return +true+ if the given node has changed.
    def node_changed?(node)
      item_changed?(unique_id(:node_content, node.alcn)) ||
        item_changed?(unique_id(:node_meta_info, node.alcn)) ||
        (@cached[:node_dependencies][node.alcn] || []).any? {|uid| item_changed?(uid)}
    end

    #######
    private
    #######

    # Return +true+ if the given item has changed. See #add for a description of the item
    # parameters.
    def item_changed?(uid)
      if !@cached[:item_data].has_key?(uid)
        true
      else
        item_tracker(uid.first).changed?(uid.last, @cached[:item_data][uid]) #TODO: probably cache this result
      end
    end

    # Return the unique ID for the given item handled by the item tracker extension object specified
    # by name.
    def unique_id(name, item)
      [name.to_sym, item_tracker(name).item_id(*item)]
    end

    # Return the item tracker extension object called name.
    def item_tracker(name)
      @instances[name] ||= extension(name).new(website)
    end

    register 'NodeContent'
    register 'NodeMetaInfo'

  end

end
