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

require 'redcloth'
require 'webgen/plugins/filehandler/page'

module ContentHandlers

  # Handles content in Textile format using RedCloth.
  class TextileHandler < ContentHandler

    plugin "TextileHandler"
    summary "Handles content in Textile format using RedCloth"
    depends_on "PageHandler"

    def initialize
      register_format( 'textile' )
    end

    def format_content( txt )
      RedCloth.new( txt ).to_html
    end

  end

end