#
#--
#
# $Id$
#
# webgen: a template based web page generator
# Copyright (C) 2004 Thomas Leitner
#
# This program is free software; you can redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program; if not,
# write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#++
#

require 'webgen/plugins/filehandler/filehandler'
require 'webgen/plugins/filehandler/directory'
require 'webgen/plugins/filehandler/page'

module FileHandlers

  # Handles page description backing files. Backing files are files that specify meta information
  # for other files. They are written in YAML and have a very easy structure:
  #
  #    filename1.html:
  #      lang1:
  #        metainfo1: value1
  #        metainfo2: value2
  #      lang2:
  #        metainfo21: value21
  #
  #    dir1/../dir1/filenam2.html:
  #      lang1:
  #        title: New titel by backing file
  #
  #    /index.html:
  #      lang1:
  #        title: YES!!!
  #
  # As you can see, you can use relative and absoulte paths in the filenames. However, you cannot
  # specify meta information for files which are in one of the parent directories of the backing
  # file. These backing files are very useful if you are using page description files which do not
  # support meta information, e.g. HTML fragment files.
  #
  # Using backing files you can add virtual files and directories. If the file specified in the
  # entry does not exist, a virtual page node for that entry will be created. This will also create
  # the whole directory tree this virtual node is in. This allows you, for example, to add external
  # items to the menu. You need to specify the +dest+ meta information which points to the actual
  # location of the referenced page. If the virtual page references an external page, you have to
  # add the +external+ meta information (i.e. set +external+ to +true+).
  class BackingFileHandler < DefaultHandler

    plugin "BackingFileHandler"
    summary "Handles backing files for page file"

    depends_on 'FileHandler'

    EXT = 'info'

    def initialize
      extension( EXT, BackingFileHandler )
      Webgen::Plugin['FileHandler'].add_msg_listener( :AFTER_DIR_READ, method( :process_backing_file ) )
    end

    def create_node( path, parent )
      node = Node.new parent
      node['virtual'] = true #TODO can be removed?
      node['src'] = node['dest'] = node['title'] = File.basename( path )
      node['content'] = YAML::load( File.new( path ) )
      node
    end

    def write_node( node )
      # nothing to write
    end

    #######
    private
    #######

    def process_backing_file( dirNode )
      backingFiles = dirNode.find_all do |child| /\.#{EXT}$/ =~ child['src'] end
      return if backingFiles.length == 0

      backingFiles.each do |backingFile|
        backingFile['content'].each do |filename, data|
          backedFile = dirNode.get_node_for_string( filename )
          if backedFile
            data.each do |language, fileData|
              langFile = Webgen::Plugin['PageHandler'].get_lang_node( backedFile, language )
              next unless langFile['lang'] == language

              self.logger.info { "Setting meta info data on file <#{langFile.recursive_value( 'dest' )}>" }
              langFile.metainfo.update( fileData )
            end
          else
            add_virtual_node( dirNode, filename, data )
          end
        end
      end
    end


    def add_virtual_node( dirNode, path, data )
      dirname = File.dirname( path ).sub( /^.$/, '' )
      filename = File.basename( path )
      dirNode = create_path( dirname, dirNode )

      data.each do |language, filedata|
        filedata['lang'] = language

        handler = VirtualPageHandler.new
        handler.set_file_data( filedata )
        pageNode = handler.create_node( filename, dirNode )
        unless pageNode.nil?
          pageNode['processor'] = Webgen::Plugin['VirtualPageHandler']
          dirNode.add_child( pageNode )
        end

        self.logger.info { "Created virtual node '#{filename}' (#{language}) in <#{dirNode.recursive_value( 'dest' )}> referencing '#{node['dest']}'" }
      end
    end


    def create_path( dirname, dirNode )
      if /^#{File::SEPARATOR}/ =~ dirname
        node = Node.root( dirNode )
        dirname = dirname[1..-1]
      else
        node = dirNode
      end

      parent = node
      dirname.split( File::SEPARATOR ).each do |element|
        case element
        when '..'
          node = node.parent
        else
          node = node.find do |child| /^#{element}#{File::SEPARATOR}?$/ =~ child['src'] end
        end
        if node.nil?
          node = FileHandlers::DirHandler::DirNode.new( parent, element )
          node['processor'] = Webgen::Plugin['VirtualDirHandler']
          parent.add_child( node )
          self.logger.info { "Created virtual directory <#{node.recursive_value( 'dest' )}>" }
        end
        parent = node
      end

      return node
    end

  end


  # Handles virtual directories, that is, directories that do not exist in the source tree.
  class VirtualDirHandler < DirHandler

    plugin "VirtualDirHandler"
    summary "Handles virtual directories"
    depends_on "DirectoryHandler"

    def write_node( node )
    end

  end

  # Handles virtual pages, that is, pages that do not exist in the source tree.
  class VirtualPageHandler < PagePlugin

    plugin "VirtualPageHandler"
    summary "Handles virtual pages"
    depends_on "PageHandler"

    def set_file_data( data )
      @data = data
    end

    def get_file_data( name )
      @data || {}
    end

    def write_node( node )
    end

  end

end