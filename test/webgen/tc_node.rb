require 'test/unit'
require 'webgen/node'
require 'setup'

class NodeTest < Test::Unit::TestCase

  def setup
    @n = Hash.new
    @n['external'] = Node.new( nil )
    @n['external']['dest'] = 'http://webgen.rubyforge.org'

    @simpleHash = { 'test' => 'hello', 'test1' => 'hello1' }
    @n['simple'] = Node.new( nil )
    @n['simple'].metainfo.update( @simpleHash )

    @n['root'] = Node.new( nil )
    @n['root']['dest'] = 'root/'
    @n['root/file1'] = create_node( @n['root'] )
    @n['root/file1']['dest'] = 'file1'
    @n['root/file1']['otherdest'] = 'file1o'
    @n['root/virtdir1'] = create_node( @n['root'] )
    @n['root/virtdir1']['virtual'] = true
    @n['root/virtdir1']['dest'] = 'virtdir1/'
    @n['root/virtdir1/file2'] = create_node( @n['root/virtdir1'] )
    @n['root/virtdir1/file2']['dest'] = 'file2'
    @n['root/dir2'] = create_node( @n['root'] )
    @n['root/dir2']['dest'] = 'dir2/'
    @n['root/dir2/file3'] = create_node( @n['root/dir2'] )
    @n['root/dir2/file3']['dest'] = 'file3'
    @n['root/dir2/file4'] = create_node( @n['root/dir2'] )
    @n['root/dir2/file4']['dest'] = 'file4'
    @n['root/dir2/dir3'] = create_node( @n['root/dir2'] )
    @n['root/dir2/dir3']['dest'] = 'dir3/'
    @n['root/dir4'] = create_node( @n['root'] )
    @n['root/dir4']['dest'] = 'dir4/'
  end

  def create_node( parent )
    node = Node.new( parent )
    parent.add_child( node )
    node
  end

  def teardown
  end

  def test_initialize
    assert_equal( nil, Node.new( nil ).parent )
    assert_equal( 'test', Node.new( 'test' ).parent )
    assert_equal( {}, Node.new( nil ).metainfo )
  end

  def test_brackets
    @simpleHash.each {|k,v| assert_equal( v, @n['simple'][k] )}
    assert_nil( @n['simple']['notinhash'] )
  end

  def test_brackets_assign
    @n['simple']['notinhash'] = 50
    assert_equal( 50, @n['simple']['notinhash'] )
  end

  def test_recursive_value
    assert_equal( 'root/file1', @n['root/file1'].recursive_value( 'dest' ) )
    assert_equal( 'root/file2', @n['root/virtdir1/file2'].recursive_value( 'dest' ) )
    assert_equal( 'root/virtdir1/file2', @n['root/virtdir1/file2'].recursive_value( 'dest', false ) )

    assert_equal( 'file1o', @n['root/file1'].recursive_value( 'otherdest' ) )
  end

  def test_relpath_to_node
    assert_raise( NoMethodError ) { @n['root/file1'].relpath_to_node( nil ) }

    assert_equal( '.', @n['root/file1'].relpath_to_node( @n['root'] ) )
    assert_equal( '.', @n['root/file1'].relpath_to_node( @n['root'], false ) )
    assert_equal( '.', @n['root/dir2'].relpath_to_node( @n['root'] ) )
    assert_equal( '.', @n['root/virtdir1/file2'].relpath_to_node( @n['root'] ) )
    assert_equal( '..', @n['root/dir2/file3'].relpath_to_node( @n['root'] ) )
    assert_equal( '..', @n['root/dir2/file3'].relpath_to_node( @n['root/file1'], false ) )
    assert_equal( '../file1', @n['root/dir2/file3'].relpath_to_node( @n['root/file1'] ) )
    assert_equal( '..', @n['root/dir2/file3'].relpath_to_node( @n['root/dir2'], false ) )
    assert_equal( '../dir2/', @n['root/dir2/file3'].relpath_to_node( @n['root/dir2'] ) )
    assert_equal( '../virtdir1/', @n['root/dir2/file3'].relpath_to_node( @n['root/virtdir1'] ) )
    assert_equal( '.', @n['root/dir2/file3'].relpath_to_node( @n['root/dir2/file4'], false ) )

    assert_equal( '', @n['root/file1'].relpath_to_node( @n['external'] ) )
  end

  def test_node_for_string
    assert_equal( @n['root/file1'], @n['root'].node_for_string( 'file1' ) )
    assert_nil( @n['root'].node_for_string( 'file2' ) )
    assert_equal( @n['root/virtdir1/file2'], @n['root'].node_for_string( 'virtdir1/file2' ) )
    assert_equal( @n['root/file1'], @n['root/virtdir1/file2'].node_for_string( 'file1' ) )
    assert_equal( @n['root/dir2/file3'], @n['root/virtdir1/file2'].node_for_string( '/dir2/file3' ) )
  end

  def test_node_for_string_question
    assert( @n['root'].node_for_string?( 'file1' ) )
    assert( !@n['root'].node_for_string?( 'file2' ) )
  end

  def test_level
    assert_equal( 1, @n['root'].level )
    assert_equal( 2, @n['root/dir2'].level )
    assert_equal( 1, @n['root/file1'].level )
    assert_equal( 1, @n['root/virtdir1/file2'].level )
    assert_equal( 2, @n['root/virtdir1/file2'].level( false ) )
    assert_equal( 2, @n['root/dir2/file3'].level )
  end

  def test_in_subtree_question
    assert( !@n['root/file1'].in_subtree?( @n['root/dir2/file3'] ) )
    assert( @n['root/dir2/file3'].in_subtree?( @n['root/dir2'] ) )
    assert( @n['root/dir2/file3'].in_subtree?( @n['root/dir2/file4'] ) )
    assert( @n['root/file1'].in_subtree?( @n['root/virtdir1/file2'] ) )
    assert( @n['root/dir2/dir3'].in_subtree?( @n['root/dir2'] ) )
    assert( !@n['root/dir2/dir3'].in_subtree?( @n['root/dir4'] ) )
    assert( !@n['root/dir2'].in_subtree?( @n['root/dir4'] ) )
    assert( !@n['root/dir2/file3'].in_subtree?( @n['root/dir4'] ) )
  end

  def test_root
    assert_equal( @n['root'], Node.root( @n['root/dir2/file3'] ) )
  end

end