# -*- encoding: utf-8 -*-

require 'minitest/autorun'
require 'webgen/source/stacked'

class TestSourceStacked < MiniTest::Unit::TestCase

  class TestSource
    def initialize(paths); @paths = paths; end
    def paths; Set.new(@paths); end
  end

  def test_initialize
    source = Webgen::Source::Stacked.new(nil)
    assert_equal([], source.stack)
    source = Webgen::Source::Stacked.new(nil, {'/dir' => 6})
    assert_equal([['/dir', 6]], source.stack)
  end

  def test_paths
    path1 = MiniTest::Mock.new
    path1.expect(:mount_at, 'path1', ['/'])
    path2 = MiniTest::Mock.new
    path2.expect(:mount_at, 'path2', ['/hallo/'])

    source = Webgen::Source::Stacked.new(nil, '/' => TestSource.new([path1]), '/hallo/' => TestSource.new([path2]))
    assert_equal(Set.new(['path1', 'path2']), source.paths)

    path1.verify
    path2.verify
  end

end