require 'yaml'
require 'ostruct'
require 'webgen/plugin'
require 'webgen/configuration'
require 'webgen/plugins/filehandler/picturegallery'
require 'Qt'
# Error when loading Qt before RMagick -> error in RMagick undefined method `display' for class `Magick::Image'
# report that to qtruby team and RMagick team

#TODO

class Gallery

  attr_accessor :meta
  attr_accessor :relpath

  def initialize
    set_default_values
    @relpath = '.'
  end

  def []( name )
    @meta[name]
  end

  def []=( name, value )
    @meta[name] = value
  end

  def set_default_values
    @meta = {}
    Webgen::Plugin.config[FileHandlers::PictureGalleryFileHandler].params.each do |name, data|
      @meta[name] = data.value
    end
    @meta['mainPage'] = nil
    @meta['galleryPages'] = nil
    @meta['thumbnailSize'] = nil
  end

  def read_file( filename )
    filedata = YAML::load( File.read( filename ) )

    set_default_values
    filedata.each {|name, data| @meta[name] = data }
    @relpath = File.dirname( filename )
  end

  def write_file( filename )
    File.open( filename, 'w+' ) {|file| file.write( @meta.to_yaml ) }
    @relpath= File.dirname( filename )
  end

end


class ImageViewer < Qt::Frame

  def initialize( p )
    super( p )
    setFrameStyle( Qt::Frame::StyledPanel | Qt::Frame::Sunken )
    set_image
  end

  def set_image( filename = nil)
    filename = File.join( Webgen::Configuration.data_dir, 'images/webgen_logo.png' ) if filename.nil?
    @image = Qt::Image.new( filename )
    update
  end

  def drawContents( painter )
    return if @image.nil?
    width = contentsRect.width
    height = contentsRect.height
    image = ( width > @image.width && height > @image.height ? @image : @image.smoothScale( width, height, Qt::Image::ScaleMin ) )
    painter.drawImage( contentsRect.left + (width - image.width) / 2, contentsRect.top + (height - image.height) / 2, image )
  end

  def sizeHint
    Qt::Size.new( 320, 200 )
  end

end


class MetaTableNameItem < Qt::TableItem

  def initialize( table, text = '' )
    super( table, Qt::TableItem::OnTyping )
    setReplaceable( false )
    setText( text )
    add_text_to_list( text )
  end

  def createEditor
    cb = Qt::ComboBox.new( table.viewport )
    cb.setEditable( true )
    cb.setAutoCompletion( true )
    cb.insertStringList( table.meta_items )
    cb.setCurrentText( text )
    cb
  end

  def setContentFromEditor( widget )
    setText( widget.currentText )
    add_text_to_list( widget.currentText )
  end

  def add_text_to_list( text )
    unless text.nil? || text.empty? || table.meta_items.include?( text )
      table.meta_items << text
      table.meta_items.sort!
    end
  end

end

class MetaTableValueItem < Qt::TableItem

  def initialize( table, text = '' )
    super( table, Qt::TableItem::OnTyping )
    setContent( text )
  end

  def setContent( content )
    setText( content.to_s )
  end

  def getContent
    case text
    when 'true' then true
    when 'false' then false
    when 'nil' then nil
    when /\d+/ then text.to_i
    else text
    end
  end

end


class MetaDataTable < Qt::Table

  slots 'value_changed(int, int)'

  attr_reader :meta_items

  def initialize( p, meta_items = [], exclude_items = [] )
    super( 1, 2, p )
    @meta_items = meta_items.sort!
    @exclude_items = exclude_items
    horizontalHeader.setLabel( 0, 'Name' )
    horizontalHeader.setLabel( 1, 'Value' )
    setSelectionMode( Qt::Table::Single )
    setItem( 0, 0, MetaTableNameItem.new( self ) )
    setItem( 0, 1, MetaTableValueItem.new( self ) )

    connect( horizontalHeader, SIGNAL('clicked(int)'), self, SLOT('setFocus()') )
    connect( verticalHeader, SIGNAL('clicked(int)'), self, SLOT('setFocus()') )
    connect( self, SIGNAL('valueChanged(int, int)'), self, SLOT('value_changed( int, int )') )
  end

  def activateNextCell
    activate = endEdit( currentRow, currentColumn, true, false )
    oldRow = currentRow
    oldCol = currentColumn

    setCurrentCell( currentColumn == 1 ? (currentRow == numRows - 1 ? 0 : currentRow + 1) : currentRow,
                    (currentColumn + 1) % 2 )
    setCurrentCell( oldRow, oldCol ) if !activate
  end

  def endEdit( row, col, accept, replace )
    activate_next_cell = true
    w = cellWidget( row, col )
    if col == 0 && !w.nil?
      if keys( (0...row).to_a + (row+1..numRows-1).to_a ).find {|t| t == w.currentText && t != '' }
        msg = "You can't add duplicate entries!"
      elsif @exclude_items.include?( w.currentText )
        msg = "This meta information can only be defined via other controls!"
      end
      if msg
        Qt::MessageBox.information( self, "Error adding entry", msg )
        accept = false
        activate_next_cell = false
      end
    end
    super( row, col, accept, replace )
    activate_next_cell
  end

  def fill( items )
    setNumRows( items.length + 1 )
    items.each_with_index do |data, index|
      setItem( index, 0, MetaTableNameItem.new( self, data[0] ) )
      setItem( index, 1, MetaTableValueItem.new( self, data[1] ) )
    end
    setItem( items.length, 0, MetaTableNameItem.new( self ) )
    setItem( items.length, 1, MetaTableValueItem.new( self ) )
  end

  def keys( rows = (0..(numRows-1)).to_a )
    retval = []
    rows.each do |i|
      retval << text( i, 0 )
    end
    retval
  end

  def meta_info
    retval = {}
    0.upto( numRows - 2 ) do |i|
      retval[text( i, 0 )] = item( i, 1 ).getContent
    end
    retval
  end

  def value_changed( row, col )
    col0empty = text( row, 0 ).nil? || text( row, 0).empty?
    col1empty = text( row, 1 ).nil? || text( row, 1).empty?
    if row == numRows - 1 && (!col0empty || !col1empty)
      setNumRows( numRows + 1 )
      setItem( numRows - 1, 0, MetaTableNameItem.new( self ) )
      setItem( numRows - 1, 1, MetaTableValueItem.new( self ) )
    elsif !(row == numRows - 1) && col0empty && col1empty
      removeRow( row )
    end
  end

  def keyReleaseEvent( event )
    if event.key == Qt::Key_Delete
      if currentSelection == -1
        setText( currentRow, currentColumn, '' )
        emit valueChanged( currentRow, currentColumn )
      else
        sel = selection( currentSelection )
        sel.topRow.upto( sel.bottomRow ) do |row|
          sel.leftCol.upto( sel.rightCol) do |col|
            setText( row, col, '' )
            emit valueChanged( row, col )
          end
        end
      end
    else
      event.ignore
    end
  end

end


class MyTextEdit < Qt::TextEdit

  signals 'myReturnPressed()'

  def keyPressEvent( event )
    if (event.key == Qt::Key_Return || event.key == Qt::Key_Enter) && (event.state & Qt::ControlButton == Qt::ControlButton)
      emit myReturnPressed()
    else
      super
    end
  end

end


class GalleryWindow < Qt::MainWindow

  slots 'new()', 'open()', 'save()', 'save_as()', 'image_selected(const QString &)',
        'init_image_list()', 'select_next_image()', "assign_pic_names()"

  def initialize
    super
    setCaption( "Webgen Gallery Editor" )
    setIcon( Qt::Pixmap.new( File.join( Webgen::Configuration.data_dir, 'images/webgen_logo.png' ) ) )
    setIconText( "Webgen Gallery Editor" )

    @gallery = nil
    @curfile = nil
    setup_menus
    setup_window
    centralWidget.setEnabled( false )
  end

  def new
    @gallery = Gallery.new
    save_as
    init_widgets
  end

  def open
    openDialog = Qt::FileDialog.new( '.', 'Gallery files (*.gallery)', self, 'Open file...', true )
    openDialog.setMode( Qt::FileDialog::ExistingFile )
    open_file( openDialog.selectedFile ) if openDialog.exec == Qt::Dialog::Accepted
  end

  def open_file( file )
    @curfile = file
    @gallery = Gallery.new
    @gallery.read_file( file )
    init_widgets
  end

  def save
    update_gallery
    @gallery.write_file( @curfile )
  end

  def save_as
    saveDialog = Qt::FileDialog.new( '.', 'Gallery files (*.gallery)', self, 'Select new file...', true )
    saveDialog.setMode( Qt::FileDialog::AnyFile )
    if saveDialog.exec == Qt::Dialog::Accepted
      fname = saveDialog.selectedFile
      fname += '.gallery' if File.extname( fname ) == ''
      @gallery.write_file( fname )
      @curfile = fname
    end
  end

  def image_selected( name )
    save_image_meta_info
    @last_selected_image = name

    if @gallery[name]
      @imageTitle.setText( @gallery[name].delete( 'title' ) )
      @imageDescription.setText( @gallery[name].delete( 'description' ) )
      @picMetaTable.fill( @gallery[name] )
    end
    @image.set_image( File.join( @gallery.relpath, name ) )
  end

  def select_next_image
    if @imageList.currentItem == @imageList.count - 1
      @imageList.setCurrentItem( 0 ) if @imageList.count > 0
    else
      @imageList.setCurrentItem( @imageList.currentItem + 1 )
    end
  end

  def assign_pic_names
    0.upto( @imageList.count - 1 ) do |i|
      @gallery[@imageList.text( i )] ||= {}
      if @gallery[@imageList.text( i )]['title'].nil? || @gallery[@imageList.text( i )]['title'] == ''
        @gallery[@imageList.text( i )]['title'] = @imageList.text( i )
      end
    end
  end

  #######
  private
  #######

  def page_meta_items
    ['title', 'description', 'orderInfo', 'template', 'inMenu']
  end

  def gallery_items
    ['title', 'layout', 'files', 'picturesPerPage',
     'picturePageInMenu', 'galleryPageInMenu', 'mainPageInMenu',
     'picturePageTemplate', 'galleryPageTemplate', 'mainPageTemplate',
     'galleryPages', 'mainPage', 'galleryOrderInfo', 'thumbnailSize' ]
  end

  def init_widgets
    return if @gallery.nil?

    gallery_items.each do |t|
      case @widgets[t]
      when Qt::LineEdit then @widgets[t].setText( @gallery[t] )
      when Qt::SpinBox then @widgets[t].setValue( @gallery[t] )
      when Qt::CheckBox then @widgets[t].setChecked( @gallery[t] )
      when Qt::ComboBox then @widgets[t].setCurrentText( @gallery[t] )
      when MetaDataTable then @widgets[t].fill( @gallery[t] )
      end
    end
    @picMetaTable.fill( [] )
    init_image_list
    @image.set_image
    centralWidget.setEnabled( true )
  end

  def update_gallery
    items = gallery_items
    items.each do |t|
      case @widgets[t]
      when Qt::LineEdit then @gallery[t] = @widgets[t].text
      when Qt::SpinBox then @gallery[t] = @widgets[t].value
      when Qt::CheckBox then @gallery[t] = @widgets[t].checked?
      when Qt::ComboBox then @gallery[t] = @widgets[t].currentText
      when MetaDataTable then @gallery[t] = @widgets[t].meta_info
      end
    end
    images = []
    0.upto( @imageList.numRows ) {|i| images << @imageList.text( i ) }

    save_image_meta_info
    @gallery.meta.delete_if do |name, data|
      !images.include?( name ) && !items.include?( name )
    end
  end

  def save_image_meta_info
    if @last_selected_image
      @gallery[@last_selected_image] = @picMetaTable.meta_info
      @gallery[@last_selected_image]['title'] = @imageTitle.text
      @gallery[@last_selected_image]['description'] = @imageDescription.text
    end
  end

  def init_image_list
    @imageList.clear
    images = Dir[File.join( @gallery.relpath, @widgets['files'].text)].collect {|i| i.sub( /#{@gallery.relpath + File::SEPARATOR}/, '' ) }
    images.each {|i| @imageList.insertItem( i ) }
    @last_selected_image = nil
  end

  def setup_menus
    filemenu = Qt::PopupMenu.new( self )
    filemenu.insertItem( "&New...", self, SLOT("new()"), Qt::KeySequence.new( CTRL+Key_N ) )
    filemenu.insertItem( "&Open...", self, SLOT("open()"), Qt::KeySequence.new( CTRL+Key_O ) )
    filemenu.insertItem( "&Save", self, SLOT("save()"), Qt::KeySequence.new( CTRL+Key_S ) )
    filemenu.insertItem( "&Save as...", self, SLOT("save_as()") )
    filemenu.insertItem( "&Quit", $app, SLOT("quit()"), Qt::KeySequence.new( CTRL+Key_Q ) )

    picmenu = Qt::PopupMenu.new( self )
    picmenu.insertItem( "&Assign default names", self, SLOT("assign_pic_names()") )

    menubar = Qt::MenuBar.new( self )
    menubar.insertItem( "&File", filemenu )
    menubar.insertItem( "&Pictures", picmenu )
  end

  def setup_window
    mainFrame = Qt::Widget.new( self )

    @widgets = {}
    labels = {}
    @widgets['title'] = Qt::LineEdit.new( mainFrame )
    labels['title'] = [0, Qt::Label.new( @widgets['title'], "Gallery title:", mainFrame )]

    @widgets['files'] = Qt::LineEdit.new( mainFrame )
    connect( @widgets['files'], SIGNAL('textChanged(const QString&)'), self, SLOT('init_image_list()') )
    labels['files'] = [1, Qt::Label.new( @widgets['files'], "File pattern:", mainFrame )]

    @widgets['layout'] = Qt::ComboBox.new( true, mainFrame )
    @widgets['layout'].setMaximumWidth( 200 )
    Webgen::Plugin.config[PictureGalleryLayouter::DefaultGalleryLayouter].layouts.keys.each do |name|
      @widgets['layout'].insertItem( Qt::Pixmap.new( File.join( Webgen::Configuration.data_dir, 'gallery-creator', "#{name}.png" ) ), \
                                     name )
    end
    @widgets['layout'].listBox.setMinimumWidth( @widgets['layout'].listBox.maxItemWidth + 20 )
    labels['layout'] = [2, Qt::Label.new( @widgets['layout'], "Gallery layout:", mainFrame )]

    @widgets['picturesPerPage'] = Qt::SpinBox.new( 0, 1000, 1, mainFrame )
    labels['picturesPerPage'] = [3, Qt::Label.new( @widgets['picturesPerPage'], "Pictures per page:", mainFrame )]

    @widgets['galleryOrderInfo'] = Qt::SpinBox.new( 0, 1000, 1, mainFrame )
    labels['galleryOrderInfo'] = [4, Qt::Label.new( @widgets['galleryOrderInfo'], "Start <orderInfo> for gallery pages:", mainFrame )]

    @widgets['thumbnailSize'] = Qt::LineEdit.new( mainFrame )
    @widgets['thumbnailSize'].setValidator( Qt::RegExpValidator.new( Qt::RegExp.new( "\\d+x\\d+" ), mainFrame ) )
    labels['thumbnailSize'] = [5, Qt::Label.new( @widgets['thumbnailSize'], "Thumbnail size:", mainFrame )]

    @widgets['mainPageTemplate'] = Qt::LineEdit.new( mainFrame )
    labels['mainPageTemplate'] = [6, Qt::Label.new( @widgets['mainPageTemplate'], "Template for main page:", mainFrame )]

    @widgets['galleryPageTemplate'] = Qt::LineEdit.new( mainFrame )
    labels['galleryPageTemplate'] = [7, Qt::Label.new( @widgets['galleryPageTemplate'], "Template for gallery pages:", mainFrame )]

    @widgets['picturePageTemplate'] = Qt::LineEdit.new( mainFrame )
    labels['picturePageTemplate'] = [8, Qt::Label.new( @widgets['picturePageTemplate'], "Template for picture pages:", mainFrame )]

    @widgets['mainPageInMenu'] = Qt::CheckBox.new( "Main page in menu?", mainFrame )
    labels['mainPageInMenu'] = [9, nil]

    @widgets['galleryPageInMenu'] = Qt::CheckBox.new( "Gallery pages in menu?", mainFrame )
    labels['galleryPageInMenu'] = [10, nil]

    @widgets['picturePageInMenu'] = Qt::CheckBox.new( "Picture pages in menu?", mainFrame )
    labels['picturePageInMenu'] = [11, nil]

    layout = Qt::GridLayout.new( @widgets.length, 2 )
    layout.setSpacing( 5 )
    labels.each_with_index do |data, index|
      layout.addWidget( data[1][1], data[1][0], 0 ) if data[1][1]
      layout.addWidget( @widgets[data[0]], data[1][0], 1 )
    end

    leftLayout = Qt::VBoxLayout.new
    leftLayout.setSpacing( 5 )
    leftLayout.addLayout( layout )
    leftLayout.addStretch

    @widgets['mainPage'] = MetaDataTable.new( mainFrame, page_meta_items )
    @widgets['mainPage'].setColumnWidth( 0, 150 )
    @widgets['mainPage'].setColumnWidth( 1, 150 )
    @widgets['mainPage'].setMinimumWidth( 350 )
    @widgets['galleryPages'] = MetaDataTable.new( mainFrame, page_meta_items )
    @widgets['galleryPages'].setColumnWidth( 0, 150 )
    @widgets['galleryPages'].setColumnWidth( 1, 150 )

    rightLayout = Qt::VBoxLayout.new
    rightLayout.setSpacing( 5 )
    rightLayout.addWidget( Qt::Label.new( 'Meta information for main page:', mainFrame ) )
    rightLayout.addWidget( @widgets['mainPage'] )
    rightLayout.addWidget( Qt::Label.new( 'Meta information for gallery pages:', mainFrame ) )
    rightLayout.addWidget( @widgets['galleryPages'] )

    galLayout = Qt::HBoxLayout.new
    galLayout.setSpacing( 20 )
    galLayout.addLayout( leftLayout )
    galLayout.addLayout( rightLayout )
    galLayout.setStretchFactor( rightLayout, 1 )


    @image = ImageViewer.new( mainFrame )
    @image.setSizePolicy( Qt::SizePolicy::Expanding, Qt::SizePolicy::Expanding )
    @image.setMinimumSize( 320, 200 )

    @imageTitle = Qt::LineEdit.new( mainFrame )
    imageTitle = Qt::Label.new( @imageTitle, "Title:", mainFrame )
    @imageDescription = MyTextEdit.new( mainFrame )
    @imageDescription.setTextFormat( Qt::PlainText )
    imageDescription = Qt::Label.new( @imageDescription, "Description:", mainFrame )
    connect( @imageTitle, SIGNAL('returnPressed()'), @imageDescription, SLOT('setFocus()') )
    connect( @imageDescription, SIGNAL('myReturnPressed()'), self, SLOT('select_next_image()') )
    connect( @imageDescription, SIGNAL('myReturnPressed()'), @imageTitle, SLOT('setFocus()') )

    @imageList = Qt::ListBox.new( mainFrame )
    @imageList.setMaximumWidth( 300 )
    connect( @imageList, SIGNAL('highlighted(const QString &)'), self, SLOT('image_selected( const QString &)') )
    @picMetaTable = MetaDataTable.new( mainFrame, page_meta_items - ['title', 'description'], ['title', 'description'] )
    @picMetaTable.setColumnWidth( 0, 100 )
    @picMetaTable.setColumnWidth( 1, 100 )
    @picMetaTable.setMaximumWidth( 300 )

    imageLayout = Qt::GridLayout.new( 3, 3 )
    imageLayout.setSpacing( 6 )
    imageLayout.addWidget( @imageList, 0, 0 )
    imageLayout.addMultiCellWidget( @picMetaTable, 1, 2, 0, 0 )
    imageLayout.addMultiCellWidget( @image, 0, 0, 1, 2 )
    imageLayout.addWidget( imageTitle, 1, 1 )
    imageLayout.addWidget( @imageTitle, 1, 2 )
    imageLayout.addWidget( imageDescription, 2, 1, Qt::AlignTop )
    imageLayout.addWidget( @imageDescription, 2, 2 )
    imageLayout.setRowStretch( 0, 1 )

    mainLayout = Qt::VBoxLayout.new( mainFrame )
    mainLayout.setMargin( 10 )
    mainLayout.setSpacing( 20 )
    mainLayout.addLayout( galLayout )
    mainLayout.addLayout( imageLayout )
    mainLayout.setStretchFactor( imageLayout, 1 )

    setCentralWidget( mainFrame )
  end

end

Webgen::Plugin['Configuration'].init_all

$app = Qt::Application.new( ARGV )
mainWindow = GalleryWindow.new
mainWindow.setIcon( Qt::Pixmap.new( File.join( Webgen::Configuration.data_dir, 'images/webgen_logo.png' ) ) )
$app.setMainWidget( mainWindow )
mainWindow.show
mainWindow.open_file( ARGV[0] ) if ARGV.length > 0
$app.exec
