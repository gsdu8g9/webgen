# -*- encoding: utf-8 -*-

require 'helper'
require 'ostruct'
require 'stringio'
require 'logger'
require 'webgen/path_handler/virtual'
require 'webgen/blackboard'
require 'webgen/tree'
require 'webgen/node'
require 'webgen/path'

class TestPathHandlerVirtual < MiniTest::Unit::TestCase

  class SimplePathHandler

    def initialize(virtual)
      @virtual = virtual
    end

    def create_secondary_nodes(path, content, handler)
      path.meta_info[:virtual] = true
      path.meta_info['dest_path'] ||= '<parent><basename>(.<lang>)<ext>'
      @virtual.create_nodes(path, {})
    end

  end

  CONTENT=<<EOF
\\--- !omap
- path.de.html:

- /dir/:
    title: My Dir

- /dir/file.html:

- /directory/path.en.html:
    dest_path: other.html
    title: new title

- api.html:
    dest_path: http://www.example.com
    title: Absolute

- other.html:
    dest_path: directory/path.en.html
    title: Nothing

- /dirnew/dirnew/dirnew/:
    dest_path: /
    title: root
EOF


  def setup
    @website = MiniTest::Mock.new
    @website.expect(:tree, Webgen::Tree.new(@website))
    @website.expect(:blackboard, Webgen::Blackboard.new)
    @website.expect(:config, {})
    @website.expect(:logger, Logger.new(StringIO.new))
    @website.expect(:ext, OpenStruct.new)
    @root = Webgen::Node.new(@website.tree.dummy_root, '/', '/')
    @virtual = Webgen::PathHandler::Virtual.new(@website)
    @website.ext.path_handler = SimplePathHandler.new(@virtual)
  end

  def test_create_node
    @time = Time.now
    path = Webgen::Path.new('/virtual', 'dest_path' => '<parent><basename>(.<lang>)<ext>', 'modified_at' => @time)
    nodes = @virtual.create_nodes(path, Webgen::Page.from_data(CONTENT).blocks)

    nodes.each {|n| assert_equal(path, n.node_info[:path])}

    node_de = @root.tree['/path.de.html']
    node_en = @root.tree['/directory/path.en.html']
    dir = @root.tree['/dir/']

    refute_nil(node_de)
    refute_nil(dir)
    refute_nil(node_en)
    refute_nil(@root.tree['/dirnew/dirnew/dirnew/'])

    assert_equal('new title', node_en['title'])
    assert_equal(@time.tv_usec, node_en['modified_at'].tv_usec)
    assert(node_en['no_output'])
    assert_equal('My Dir', dir['title'])
    assert_equal('directory/other.html', node_de.route_to(node_en))
    assert_equal('../path.de.html', dir.route_to(node_de))
    assert_equal('../directory/other.html', dir.route_to(node_en))

    assert_equal('http://www.example.com', @root.tree['/api.html'].dest_path)
    assert_equal('http://www.example.com', @root.tree['/path.de.html'].route_to(@root.tree['/api.html']))
  end

end