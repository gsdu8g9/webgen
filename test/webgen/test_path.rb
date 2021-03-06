# -*- encoding: utf-8 -*-

require 'minitest/autorun'
require 'webgen/path'
require 'stringio'
require 'tmpdir'

class TestPath < Minitest::Test

  def test_class_url
    assert_equal("webgen://lh/hallo", Webgen::Path.url("hallo").to_s)
    assert_equal("webgen://lh/hallo%20du", Webgen::Path.url("hallo du").to_s)
    assert_equal("webgen://lh/hall%C3%B6chen", Webgen::Path.url("hallöchen").to_s)
    assert_equal("webgen://lh/hallo#du", Webgen::Path.url("hallo#du").to_s)

    assert_equal("webgen://lh/test", Webgen::Path.url("/test").to_s)
    assert_equal("http://example.com/test", Webgen::Path.url("http://example.com/test").to_s)

    assert_equal("test", Webgen::Path.url("test", false).to_s)
    assert_equal("http://example.com/test", Webgen::Path.url("http://example.com/test", false).to_s)
  end

  def test_class_append
    assert_equal('/', Webgen::Path.append('/', '/'))
    assert_equal('/dir', Webgen::Path.append('/other', '/dir'))
    assert_equal('/dir/', Webgen::Path.append('/other', '/dir/'))
    assert_equal('/other/dir', Webgen::Path.append('/other/', 'dir'))
    assert_equal('/test/dir', Webgen::Path.append('/other', '../test/dir'))
    assert_equal('/test', Webgen::Path.append('/', '/../test'))
    assert_equal('/dir/', Webgen::Path.append('/', '/../dir/.'))

    assert_equal(Encoding::UTF_8, Webgen::Path.append('/', '/../dir/.').encoding)
    assert_equal(Encoding::UTF_8, Webgen::Path.append('/', '/**.css').encoding)
  end

  def test_class_matches_pattern
    path = '/dir/to/file.de.page'
    assert(Webgen::Path.matches_pattern?(path, '**/*'))
    assert(Webgen::Path.matches_pattern?(path, '**/file.de.PAGE'))
    assert(Webgen::Path.matches_pattern?(path, '/dir/*/file.*.page'))
    refute(Webgen::Path.matches_pattern?(path, '**/*.test'))

    path = '/dir/'
    assert(Webgen::Path.matches_pattern?(path, '/dir/'))
    assert(Webgen::Path.matches_pattern?(path, '/dir'))
    assert(Webgen::Path.matches_pattern?(path, '/*/'))
    assert(Webgen::Path.matches_pattern?(path, '/*'))

    path = '/file'
    assert(!Webgen::Path.matches_pattern?(path, '/file/'))
    assert(Webgen::Path.matches_pattern?(path, '/file'))
    assert(!Webgen::Path.matches_pattern?(path, '/*/'))
    assert(Webgen::Path.matches_pattern?(path, '/*'))

    path = '/'
    assert(Webgen::Path.matches_pattern?(path, '/'))

    path = ''
    assert(!Webgen::Path.matches_pattern?(path, '/'))

    path = '/dir/to/file.de.page#somefile.page'
    refute(Webgen::Path.matches_pattern?(path, '**/*'))
    refute(Webgen::Path.matches_pattern?(path, '/dir/*/file.*.page'))
    assert(Webgen::Path.matches_pattern?(path, '**/*#*'))
    assert(Webgen::Path.matches_pattern?(path, '**/*#*.page'))
  end

  def test_initialize_and_accessors
    check_proc = proc do |o, ppath, bn, lang, ext, cn, lcn, acn, alcn, oi, title|
      assert_kind_of(String, o.path)
      assert_equal(ppath, o.parent_path)
      assert_equal(bn, o.basename)
      assert_equal(lang, o.meta_info['lang'])
      assert_equal(ext, o.ext)
      assert_equal(cn, o.cn)
      assert_equal(lcn, o.lcn)
      assert_equal(acn, o.acn)
      assert_equal(alcn, o.alcn)
      assert_equal(oi, o.meta_info['sort_info'])
      assert_equal(title, o.meta_info['title'])
    end

    # Check directory paths
    check_proc.call(Webgen::Path.new('/'),
                    '', '/', nil, '', '/', '/', '/', '/', nil, '/')
    check_proc.call(Webgen::Path.new('/directory/'),
                    '/', 'directory', nil, '', 'directory/', 'directory/', '/directory/', '/directory/', nil, 'Directory')
    check_proc.call(Webgen::Path.new('/dir1/dir2.ext/'),
                    '/dir1/', 'dir2.ext', nil, '', 'dir2.ext/', 'dir2.ext/', '/dir1/dir2.ext/', '/dir1/dir2.ext/', nil, 'Dir2.ext')

    # Check file paths
    check_proc.call(Webgen::Path.new('/5.b_n-one.de.page'),
                    '/', 'b_n-one', 'de', 'page', 'b_n-one.page', 'b_n-one.de.page',  '/b_n-one.page', '/b_n-one.de.page', 5, 'B n one')
    check_proc.call(Webgen::Path.new('/dir/default.png'),
                    '/dir/',  'default', nil, 'png', 'default.png', 'default.png', '/dir/default.png', '/dir/default.png', nil, 'Default')
    check_proc.call(Webgen::Path.new('/default.deu.png'),
                    '/', 'default', 'de', 'png', 'default.png', 'default.de.png', '/default.png', '/default.de.png', nil, 'Default')
    check_proc.call(Webgen::Path.new('/default.tar.bz2'),
                    '/', 'default', nil, 'tar.bz2', 'default.tar.bz2', 'default.tar.bz2', '/default.tar.bz2', '/default.tar.bz2', nil, 'Default')
    check_proc.call(Webgen::Path.new('/default.en.tar.bz2'),
                    '/', 'default', 'en', 'tar.bz2', 'default.tar.bz2', 'default.en.tar.bz2', '/default.tar.bz2', '/default.en.tar.bz2', nil, 'Default')
    check_proc.call(Webgen::Path.new('/default'),
                    '/', 'default', nil, '', 'default', 'default', '/default', '/default', nil, 'Default')
    check_proc.call(Webgen::Path.new('/.htaccess'),
                    '/', '.htaccess', nil, '', '.htaccess', '.htaccess', '/.htaccess', '/.htaccess', nil, '.htaccess')
    check_proc.call(Webgen::Path.new('/.htaccess.page'),
                    '/', '.htaccess', nil, 'page', '.htaccess.page', '.htaccess.page', '/.htaccess.page', '/.htaccess.page', nil, '.htaccess')
    check_proc.call(Webgen::Path.new('/.htaccess.en.page'),
                    '/', '.htaccess', 'en', 'page', '.htaccess.page', '.htaccess.en.page', '/.htaccess.page', '/.htaccess.en.page', nil, '.htaccess')
    check_proc.call(Webgen::Path.new('/5.png'),
                    '/', '5', nil, 'png', '5.png', '5.png', '/5.png', '/5.png', nil, '5')
    check_proc.call(Webgen::Path.new('/5.de.png'),
                    '/', '5', 'de', 'png', '5.png', '5.de.png', '/5.png', '/5.de.png', nil, '5')
    check_proc.call(Webgen::Path.new('/5.de.png.gz'),
                    '/', 'de', nil, 'png.gz', 'de.png.gz', 'de.png.gz', '/de.png.gz', '/de.png.gz', 5, 'De')
    check_proc.call(Webgen::Path.new('/5.de.en.gz'),
                    '/', 'de', 'en', 'gz', 'de.gz', 'de.en.gz', '/de.gz', '/de.en.gz', 5, 'De')
    check_proc.call(Webgen::Path.new('/5.66.png'),
                    '/', '66', nil, 'png', '66.png', '66.png', '/66.png', '/66.png', 5, '66')


    # Check fragment paths
    assert_raises(RuntimeError) { Webgen::Path.new("/#hallo").basename }
    assert_raises(RuntimeError) { Webgen::Path.new("/#hallo#done").basename }
    check_proc.call(Webgen::Path.new('/file#hallo'),
                    '/file', '#hallo', nil, '', '#hallo', '#hallo', '/file#hallo', '/file#hallo', nil, '#hallo')
    check_proc.call(Webgen::Path.new('/file.en.page#hallo'),
                    '/file.en.page', '#hallo', nil, '', '#hallo', '#hallo', '/file.page#hallo', '/file.en.page#hallo', nil, '#hallo')

    # Check custom cn generation
    check_proc.call(Webgen::Path.new('/dir/file.en.png', 'cn' => '<basename>-hallo(-<version>)<ext>'),
                    '/dir/', 'file', 'en', 'png', 'file-hallo.png', 'file-hallo.en.png', '/dir/file-hallo.png', '/dir/file-hallo.en.png', nil, 'File')
    check_proc.call(Webgen::Path.new('/dir/file.en.png', 'cn' => '<basename>(-<version>)<ext>', 'version' => 'hallo'),
                    '/dir/', 'file', 'en', 'png', 'file-hallo.png', 'file-hallo.en.png', '/dir/file-hallo.png', '/dir/file-hallo.en.png', nil, 'File')

    # Check title generation
    check_proc.call(Webgen::Path.new('/someFile.png'),
                    '/', 'someFile', nil, 'png', 'someFile.png', 'someFile.png', '/someFile.png', '/someFile.png', nil, 'SomeFile')

    # Check general exceptions
    assert_raises(RuntimeError) { Webgen::Path.new('/no_basename#').basename }
    assert_raises(RuntimeError) { Webgen::Path.new('relative.page').basename }

    # Check path with set meta infos
    mi = {'title' => 'Hello'}
    path = Webgen::Path.new('/test.en.file', mi)
    assert_equal('/test.en.file', path.path)
    assert_equal('Hello', path.meta_info['title'])
    path = Webgen::Path.new('/test.en.file', 'version' => 'default')
    assert_equal('/test.en.file', path.alcn)
    path = Webgen::Path.new('/test.en.file', 'version' => 'other')
    assert_equal('/test-other.en.file', path.alcn)

    path = Webgen::Path.new('/test.eo.file', mi)
    assert_equal('eo', path.meta_info['lang'])

    # Check other accessors
    path = Webgen::Path.new('/test/')
    assert_nil(path['key'])
    path['key'] = 'val'
    assert_equal('val', path['key'])
    assert_equal('val', path.meta_info['key'])

    # Check ext= setter
    path = Webgen::Path.new('/test.file')
    path.ext = 'dir'
    assert_equal('/test.dir', path.alcn)

    path = Webgen::Path.new('/test/')
    path.ext = 'dir'
    assert_equal('/test.dir/', path.alcn)

    path = Webgen::Path.new('/test.dir/')
    assert_equal('/test.dir/', path.alcn)
    path.ext = 'other'
    assert_equal('/test.dir.other/', path.alcn)
  end

  def test_mount_at
    path = Webgen::Path.new('/test.de.page')
    assert_raises(ArgumentError) { path.mount_at('no_start_slash/') }
    assert_raises(ArgumentError) { path.mount_at('/no_end_slash') }
    assert_raises(ArgumentError) { path.mount_at('/no_with_hash#_char/') }
    assert_raises(ArgumentError) { path.mount_at('/', 'no_start_slash/') }
    assert_raises(ArgumentError) { path.mount_at('/', '/no_end_slash') }
    assert_raises(ArgumentError) { path.mount_at('/', '/no_with_hash#_char/') }
    assert_raises(ArgumentError) { path.basename; path.mount_at('/') }

    path = Webgen::Path.new('/test.de.page').mount_at('/somedir/')
    assert_equal('/somedir/test.de.page', path.path)
    assert_equal('/somedir/', path.parent_path)

    path = Webgen::Path.new('/').mount_at('/somedir/')
    assert_equal('/somedir/', path.path)
    assert_equal('/', path.parent_path)
    assert_equal('somedir/', path.cn)
    assert_equal('Somedir', path.meta_info['title'])

    path = Webgen::Path.new('/source/test.rb').mount_at('/', '/source/')
    assert_equal('/test.rb', path.path)
    assert_equal('/', path.parent_path)
    assert_equal('test.rb', path.cn)
    assert_equal('Test', path.meta_info['title'])

    path = Webgen::Path.new('/source/').mount_at('/', '/source/')
    assert_equal('/', path.path)
    assert_equal('', path.parent_path)
    assert_equal('/', path.cn)
    assert_equal('/', path.meta_info['title'])

    path = Webgen::Path.new('/') { StringIO.new('test') }.mount_at('/somedir/')
    assert_equal('test', path.data)
  end

  def test_dup
    path = Webgen::Path.new('/test.de.page')
    dupped = path.dup
    dupped.meta_info['title'] = 'changed'
    assert_equal('Test', path.meta_info['title'])
  end

  def test_io
    path = Webgen::Path.new('/test.de.page')
    assert_raises(RuntimeError) { path.io }
    path = Webgen::Path.new('/test.de.page') { StringIO.new('hallo') }
    assert_equal('hallo', path.data)
    assert_equal('hallo', path.io {|f| f.read })

    Dir.mktmpdir('webgen-path') do |dir|
      File.open(File.join(dir, 'src'), 'wb+') {|f| f.write("\xEF\xBB\xBF\303\274")}
      path = Webgen::Path.new('/test') {|mode| File.open(File.join(dir, 'src'), mode) }
      assert_equal(2, path.data('r:UTF-8').length)
      assert_equal(5, path.data('rb').length)
      path['io_open_mode'] = 'r:BOM|UTF-8'
      assert_equal(1, path.data.length)
    end

    path = Webgen::Path.new('/test.page')
    path.set_io(&proc { StringIO.new('hallo') })
    assert_equal('hallo', path.data)

    path.set_io { StringIO.new('hallo2') }
    assert_equal('hallo2', path.data)

    path.set_io
    assert_raises(RuntimeError) { path.data }
  end

  def test_equality
    path = Webgen::Path.new('/test.de.page')
    assert_equal('/test.de.page', path)
    assert_equal(Webgen::Path.new('/test.de.page'), path)
    refute_equal(5, path)
  end

  def test_comparison
    p1 = Webgen::Path.new('/test.de.page')
    p2 = Webgen::Path.new('/test.en.page')
    assert_equal(0, p1 <=> p1)
    assert_equal(-1, p1 <=> p2)
    assert_equal(1, p2 <=> p1)
  end

  def test_hashing
    path = Webgen::Path.new('test.de.page')
    h = { 'test.de.page' => :value }
    assert_equal(:value, h['test.de.page'])
    assert_equal(:value, h[path])
    assert_equal(0, (path <=> 'test.de.page'))
    h = { path => :newvalue }
    assert_nil(h['test.de.page'])
    assert_equal(:newvalue, h[Webgen::Path.new('test.de.page')])
  end

  def test_introspection
    path = Webgen::Path.new('/test.de.page')
    assert_equal('/test.de.page', path.to_s)
    assert(path.inspect.include?('/test.de.page'))
  end

end
