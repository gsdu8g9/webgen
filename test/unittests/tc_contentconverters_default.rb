require 'webgen/test'


class DefaultContentConverterTest < Webgen::PluginTestCase

  plugin_files ['webgen/plugins/contentconverters/default.rb']

  def test_call
    plugin = ContentConverters::DefaultContentConverter.new( @manager )
    assert_raises( NotImplementedError ) { plugin.call( '' ) }
  end

end
