require 'test/unit'
require 'webgen/tree'
require 'webgen/contentprocessor'

class TestContentProcessorBuilder < Test::Unit::TestCase

  def test_call
    obj = Webgen::ContentProcessor::Builder.new
    root = Webgen::Node.new(Webgen::Tree.new.dummy_root, '/', '/')
    node = Webgen::Node.new(root, 'test', 'test')
    context = Webgen::ContentProcessor::Context.new(:content => "xml.div(:path => node.absolute_lcn) { xml.strong('test') }",
                                                    :chain => [node])
    assert_equal("<div path=\"/test\">\n  <strong>test</strong>\n</div>\n", obj.call(context).content)

    context.content = 'raise "bla"'
    assert_raise(RuntimeError) { obj.call(context).content }
  end

end