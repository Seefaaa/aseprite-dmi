---
-- SOME TYPES ARE MISSING AND SOME ARE NOT CORRECTLY DEFINED
-- AND I'M JUST COMPLETING THE TYPES IN NEED
---

--- @diagnostic disable: lowercase-global

------------------- NAMESPACES -------------------

if not app then
	--- @type app
	--- @diagnostic disable-next-line: missing-fields
	app = {}
end

if not json then
	--- @type json
	--- @diagnostic disable-next-line: missing-fields
	json = {}
end

------------------- CONSTRUCTORS -------------------

--- @class Point.Params
--- @field x number
--- @field y number

if not Point then
	--- Creates a new Point object.
	--- @return Point point
	--- @overload fun(x: number, y: number): Point
	--- @overload fun(otherPoint: Point): Point
	--- @overload fun(tbl: Point.Params): Point
	--- @overload fun(tbl: number[]): Point
	function Point()
		return {}
	end
end

--- @class Color.ParamsIndex
--- @field index number

--- @class Color.ParamsRGB
--- @field red number
--- @field green number
--- @field blue number
--- @field alpha number

--- @class Color.ParamsRGB2
--- @field r number
--- @field g number
--- @field b number
--- @field a number

if not Color then
	--- Creates a new Color object.
	--- @return Color color
	--- @overload fun(r: number, g: number, b: number, a: number): Color
	--- @overload fun(index: number): Color
	--- @overload fun(params: Color.ParamsIndex|Color.ParamsRGB|Color.ParamsRGB2): Color
	--- @todo HSVA HSLA GRAY
	function Color()
		return {}
	end
end

--- @class Rectangle.Params
--- @field x number
--- @field y number
--- @field width number
--- @field height number

--- @class Rectangle.Params2
--- @field x number
--- @field y number
--- @field w number
--- @field h number

if not Rectangle then
	--- Creates a new Rectangle object.
	--- @return Rectangle rectangle
	--- @overload fun(otherRectangle: Rectangle): Rectangle
	--- @overload fun(x: number, y: number, width: number, height: number): Rectangle
	--- @overload fun(params: Rectangle.Params|Rectangle.Params2|(number)[]): Rectangle
	function Rectangle()
		return {}
	end
end

--- @class Size.Params
--- @field width number
--- @field height number

--- @class Size.Params2
--- @field w number
--- @field h number

if not Size then
	--- Creates a new Size object.
	--- @return Size size
	--- @overload fun(width: number, height: number): Size
	--- @overload fun(otherSize: Size): Size
	--- @overload fun(params: Size.Params|Size.Params2|(number)[]): Size
	function Size()
		return {}
	end
end

--- @class Image.Params
--- @field fromFile string

if not Image then
	--- Creates a new Image object.
	--- @return Image image
	--- @overload fun(width: number, height: number, colorMode?: ColorMode): Image
	--- @overload fun(spec: ImageSpec): Image
	--- @overload fun(sprite: Sprite): Image
	--- @overload fun(otherImage: Image): Image
	--- @overload fun(otherImage: Image, rectangle: Rectangle): Image
	--- @overload fun(params: Image.Params): Image
	function Image()
		return {}
	end
end

--- @class ImageSpec.Params
--- @field width number
--- @field height number
--- @field colorMode ColorMode
--- @field transparentColor number

if not ImageSpec then
	--- Creates a new ImageSpec object.
	--- @return ImageSpec spec
	--- @overload fun(otherImageSpec: ImageSpec): ImageSpec
	--- @overload fun(params: ImageSpec.Params): ImageSpec
	function ImageSpec()
		return {}
	end
end

--- @class Dialog.Params
--- @field title string
--- @field notitlebar? boolean
--- @field parent? Dialog
--- @field onclose? function

if not Dialog then
	--- Creates a new Dialog object.
	--- @return Dialog dialog
	--- @overload fun(title: string): Dialog
	--- @overload fun(params: Dialog.Params): Dialog
	function Dialog()
		return {}
	end
end

--- @class Sprite.Params
--- @field fromFile string

if not Sprite then
	--- Creates a new Sprite object.
	--- @return Sprite sprite
	--- @overload fun(width: number, height: number, colorMode?: ColorMode): Sprite
	--- @overload fun(spec: ImageSpec): Sprite
	--- @overload fun(otherSprite: Sprite): Sprite
	--- @overload fun(params: Sprite.Params): Sprite
	function Sprite()
		return {}
	end
end

--- @class ColorSpace.Params
--- @field sRGB boolean

--- @class ColorSpace.Params2
--- @field fromFile string

if not ColorSpace then
	--- Creates a new ColorSpace object.
	--- @return ColorSpace colorSpace
	--- @overload fun(): ColorSpace
	--- @overload fun(params: ColorSpace.Params|ColorSpace.Params2): ColorSpace
	function ColorSpace()
		return {}
	end
end

--- @class Palette.Params
--- @field fromFile string

--- @class Palette.Params2
--- @field fromResource string

if not Palette then
	--- Creates a new Palette object.
	--- @return Palette palette
	--- @overload fun(): Palette
	--- @overload fun(otherPalette: Palette): Palette
	--- @overload fun(numberOfColors: number): Palette
	--- @overload fun(params: Palette.Params|Palette.Params2): Palette
	function Palette()
		return {}
	end
end

------------------- ENUMS -------------------

if not ColorMode then
	ColorMode = {
		RGB = 1,
		GRAY = 2,
		INDEXED = 3,
		TILEMAP = 4,
	}
end

if not MouseButton then
	MouseButton = {
		LEFT = 1,
		MIDDLE = 2,
		RIGHT = 3,
		X1 = 4,
		X2 = 5,
	}
end

if not BlendMode then
	BlendMode = {
		NORMAL = 0,
		SRC = 1,
		MULTIPLY = 2,
		SCREEN = 3,
		OVERLAY = 4,
		DARKEN = 5,
		LIGHTEN = 6,
		COLOR_DODGE = 7,
		COLOR_BURN = 8,
		HARD_LIGHT = 9,
		SOFT_LIGHT = 10,
		DIFFERENCE = 11,
		EXCLUSION = 12,
		HSL_HUE = 13,
		HSL_SATURATION = 14,
		HSL_COLOR = 15,
		HSL_LUMINOSITY = 16,
		ADDION = 17,
		SUBTRACT = 18,
		DIVIDE = 19,
	}
end

------------------- TYPES -------------------

--- @class app
--- @field apiVersion number
---- @field version Version TODO
--- @field isUIAvailable boolean
--- @field alert (fun(text: string): number)|(fun(params: app.alert.Params): number)
--- @field transaction fun(name?: string, callback: function)
--- @field sprite Sprite
--- @field sprites (Sprite)[]
--- @field frame Frame|number
---- @field site Site TODO
---- @field range Range TODO
--- @field image Image
--- @field layer Layer
--- @field tag Tag
---- @field tool Tool TODO
---- @field brush Brush TODO
--- @field editor Editor
---- @field window Window TODO
--- @field command table<string, function>
--- @field pixelColor app.pixelColor
--- @field fgColor Color
--- @field bgColor Color
--- @field params table
--- @field events app.events
--- @field theme app.theme
--- @field fs app.fs

--- @class app.pixelColor
--- @field rgba fun(r: number, g: number, b: number, a: number): number

--- @class app.events
--- @field on fun(self: app.events, name: string, callback: function): number
--- @field off fun(self: app.events, id: number)

--- @class app.theme
--- @field color (Color)[]

--- @class app.fs
--- @field pathSeparator string
--- @field filePath fun(filename: string): string
--- @field fileName fun(filename: string): string
--- @field fileExtension fun(filename: string): string
--- @field fileTitle fun(filename: string): string
--- @field filePathAndTitle fun(filename: string): string
--- @field normalizePath fun(path: string): string
--- @field joinPath fun(path: string, ...: string): string
--- @field currentPath string
--- @field appPath string
--- @field tempPath string
--- @field userDocsPath string
--- @field userConfigPath string
--- @field isFile fun(path: string): boolean
--- @field isDirectory fun(path: string): boolean
--- @field fileSize fun(filename: string): number
--- @field listFiles fun(path: string): table
--- @field makeDirectory fun(path: string): boolean
--- @field makeAllDirectories fun(path: string): boolean
--- @field removeDirectory fun(path: string): boolean

--- @class app.alert.Params
--- @field title? string
--- @field text? string|(string)[]
--- @field buttons? string|(string)[]

--- @class json
--- Decodes a json string and returns a table.
--- @field decode fun(str: string): table
--- Encodes the given table as json.
--- @field encode fun(tbl: table): string

--- @class Plugin
--- @field name string Name of the extension.
--- @field path string Path where the extension is installed.
--- @field preferences table<string, any> It's a Lua table where you can load/save any kind of Lua value here and they will be saved/restored automatically on each session.
--- @field newCommand fun(self: Plugin, params: Plugin.CommandParams) Creates a new command that can be associated to keyboard shortcuts and it's added in the app menu in the specific `"group"`. Groups are defined in the `gui.xml` file inside the `<menus>` element.
--- @field newMenuGroup fun(self: Plugin, params: Plugin.MenuGroupParams) Creates a new menu item which will contain a submenu grouping several plugin commands.
--- @field newMenuSeparator fun(self: Plugin, params: Plugin.MenuSeparatorParams) Creates a menu separator in the given menu group, useful to separate several Plugin:newCommand.

--- @class Plugin.CommandParams
--- @field id string ID to identify this new command in `Plugin:newCommand{ id=id, ... }` calls to add several keyboard shortcuts to the same command.
--- @field title string Title of the new menu item.
--- @field group string In which existent group we should add this new menu item. Existent app groups are defined in the `gui.xml` file inside the `<menus>` element.
--- @field onclick function Function to be called when the command is executed (clicked or an associated keyboard shortcut pressed).
--- @field enabled? fun(): boolean Optional function to know if the command should be available (enabled or disabled). It should return true if the command can be executed right now. If this function is not specified the command will be always available to be executed by the user.

--- @class Plugin.MenuGroupParams
--- @field id string  ID to identify this new menu group in `Plugin:newCommand{ ..., group=id, ... }` calls to add several command/menu items as elements of this group submenu.
--- @field title string Title of the new menu group.
--- @field group string In which existent group we should add this new menu item. Existent app groups are defined in the `gui.xml` file inside the `<menus>` element.

--- @class Plugin.MenuSeparatorParams
--- @field group string In which existent group we should add this new menu item.

--- @class Image: table
--- @field clone fun(self: Image): Image
--- @field id number
--- @field version number
--- @field width number
--- @field height number
--- @field bounds Rectangle
--- @field colorMode ColorMode
--- @field spec ImageSpec
--- @field cel Cel
--- @field bytes string
--- @field rowStride number
--- @field bytesPerPixel number
--- @field clear function
--- @field drawPixel function
--- @field getPixel function
--- @field drawImage function
--- @field drawSprite function
--- @field isEqual function
--- @field isEmpty function
--- @field isPlain function
--- @field pixels function
--- @field saveAs (fun(self: Image, filename: string))|(fun(self: Image, params: Image.SaveParams))
--- @field resize function

--- @class Image.SaveParams
--- @field filename string
--- @field palette Palette

--- @class Sprite: table
--- @field width number
--- @field height number
--- @field bounds Rectangle
--- @field gridBounds Rectangle
--- @field pixelRatio Size
--- @field selection Selection
--- @field filename string
--- @field isModified boolean
--- @field colorMode ColorMode
--- @field spec ImageSpec
--- @field frames (Frame)[]
--- @field palettes (Palette)[]
--- @field layers (Layer)[]
--- @field cels (Cel)[]
--- @field tags (Tag)[]
--- @field slices (Slice)[]
--- @field backgroundLayer Layer
--- @field transparentColor number
--- @field color Color
--- @field data string
--- @field properties table
--- @field resize function
--- @field crop function
--- @field saveAs fun(self: Sprite, filename: string)
--- @field saveCopyAs function
--- @field close function
--- @field loadPalette function
--- @field setPalette function
--- @field assignColorSpace function
--- @field convertColorSpace function
--- @field newLayer fun(self: Sprite): Layer
--- @field newGroup localecategory
--- @field deleteLayer (fun(self: Sprite, layer: Layer))|(fun(self: Sprite, layerName: string)))
--- @field newFrame (fun(self: Sprite, frameNumber: number): Frame)|(fun(self: Sprite, frame: Frame): Frame))
--- @field newEmptyFrame fun(self: Sprite, frameNumber: number): Frame
--- @field deleteFrame function
--- @field newCel function
--- @field deleteCel function
--- @field newTag function
--- @field deleteTag function
--- @field newSlice function
--- @field deleteSlice function
--- @field newTileset function
--- @field deleteTileset function
--- @field newTile function
--- @field deleteTile function
--- @field flatten function
--- @field events table
--- @field tileManagementPlugin table

--- @class Color: table
--- @field red number
--- @field green number
--- @field blue number
--- @field alpha number
--- @field hsvHue number
--- @field hsvSaturation number
--- @field hsvValue number
--- @field hslHue number
--- @field hslSaturation number
--- @field hslLightness number
--- @field hue number
--- @field saturation number
--- @field value number
--- @field lightness number
--- @field index number
--- @field gray string
--- @field rgbaPixel PixelColor
--- @field grayPixel PixelColor

--- @class Rectangle: table
--- @field x number
--- @field y number
--- @field width number
--- @field height number
--- @field w number
--- @field h number
--- @field origin Point
--- @field size Size
--- @field isEmpty boolean
--- @field contains fun(self: Rectangle, otherRectangle: Rectangle): boolean
--- @field intersects fun(self: Rectangle, otherRectangle: Rectangle): boolean
--- @field intersect fun(self: Rectangle, otherRectangle: Rectangle): Rectangle
--- @field union fun(self: Rectangle, otherRectangle: Rectangle): Rectangle

--- @class Layer: table
--- @field sprite Sprite
--- @field name string
--- @field opacity number
--- @field blendMode BlendMode
--- @field layers (Layer)[]|nil
--- @field parent Sprite|Layer|nil
--- @field stackIndex number
--- @field isImage boolean
--- @field isGroup boolean
--- @field isTilemap boolean
--- @field isTransparent boolean
--- @field isBackground boolean
--- @field isEditable boolean
--- @field isVisible boolean
--- @field isContinuous boolean
--- @field isCollapsed boolean
--- @field isExpanded boolean
--- @field isReference boolean
--- @field cels (Cel)[]
--- @field color Color
--- @field data string
--- @field properties table
--- @field cel fun(self: Layer, frameNumber: number): Cel|nil
--- @field tileset Tileset

--- @class ImageSpec: table
--- @field colorMode ColorMode
--- @field width number
--- @field height number
--- @field colorSpace ColorSpace
--- @field transparentColor number

--- @class Frame: table
--- @field sprite Sprite
--- @field frameNumber number
--- @field duration number
--- @field previous Frame|nil
--- @field next Frame|nil

--- @class Point: table
--- @field x number
--- @field y number

--- @class ButtonParams
--- @field id string
--- @field label? string
--- @field text? string
--- @field selected? boolean
--- @field focus? boolean
--- @field onclick? function

--- @class Dialog: table
--- @field data table
--- @field bounds Rectangle
--- @field button fun(self: Dialog, params: Dialog.ButtonParams)
--- @field canvas fun(self: Dialog, params: Dialog.CanvasParams)
--- @field file fun(self: Dialog, params: Dialog.FileParams)
--- @field label fun(self: Dialog, params: Dialog.LabelParams)
--- @field separator fun(self: Dialog, params?: Dialog.SeparatorParams)
--- @field entry fun(self: Dialog, params: Dialog.EntryParams)
--- @field combobox fun(self: Dialog, params: Dialog.ComboboxParams)
--- @field number fun(self: Dialog, params: Dialog.NumberParams)
--- @field check fun(self: Dialog, params: Dialog.CheckParams)
--- @field repaint fun(self: Dialog)
--- @field show fun(self: Dialog, params?: Dialog.ShowParams)
--- @field close fun(self: Dialog)

--- @class Dialog.SeparatorParams
--- @field id? string
--- @field text? string

--- @class Dialog.ButtonParams
--- @field id? string
--- @field label? string
--- @field text? string
--- @field selected? boolean
--- @field focus? boolean
--- @field onclick? function

--- @class Dialog.CanvasParams
--- @field id? string
--- @field width number
--- @field height number
--- @field onpaint? fun(ev: Dialog.CanvasEvent)
--- @field onmousedown? function
--- @field onmouseup? function
--- @field onmousemove? function
--- @field onwheel? function

--- @class Dialog.CanvasEvent
--- @field context GraphicsContext

--- @class Dialog.FileParams
--- @field id? string
--- @field filetypes? string[]
--- @field load? boolean
--- @field save? boolean
--- @field onchange? function

--- @class Dialog.LabelParams
--- @field id? string The unique identifier for the label.
--- @field label? string The label to be displayed.
--- @field text? string The text associated with the label.

--- @class Dialog.EntryParams
--- @field id? string The unique identifier for the entry.
--- @field label? string The label to be displayed.
--- @field text? string The text associated with the entry.
--- @field focus? boolean Whether the entry should be focused or not.
--- @field onchange? function The function to be called when the entry text changes.

--- @class Dialog.ComboboxParams
--- @field id? string The unique identifier for the combobox.
--- @field label? string The label to be displayed.
--- @field option? string The default option to be selected.
--- @field options? string[] The options to be displayed.
--- @field onchange? function The function to be called when the selected option changes.

--- @class Dialog.NumberParams
--- @field id? string The unique identifier for the number.
--- @field label? string The label to be displayed.
--- @field text? string The text associated with the number.
--- @field decimals? number The number of decimals to be displayed.
--- @field onchange? function The function to be called when the number changes.

--- @class Dialog.CheckParams
--- @field id? string The unique identifier for the check.
--- @field label? string The label to be displayed.
--- @field text? string The text associated with the check.
--- @field selected? boolean Whether the check should be selected or not.
--- @field onclick? function The function to be called when the check is clicked.

--- @class Dialog.ShowParams
--- @field wait boolean

--- @class Cel: table
--- @field sprite Sprite
--- @field layer Layer
--- @field frame Frame
--- @field frameNumber number
--- @field image Image
--- @field bounds Rectangle
--- @field position Point
--- @field opacity number
--- @field zIndex number
--- @field color Color
--- @field data string
--- @field properties table

--- @class Size: table
--- @field width number
--- @field height number
--- @field w number
--- @field h number
--- @field union fun(self: Size, otherSize: Size): Size

--- @class Selection: table
--- @field bounds Rectangle
--- @field origin Point
--- @field isEmpty boolean
--- @field deselect fun(self: Selection)
--- @field selectAll fun(self: Selection)
--- @field add (fun(self: Selection, rectangle: Rectangle))|(fun(self: Selection, otherSelection: Selection))
--- @field subtract (fun(self: Selection, rectangle: Rectangle))|(fun(self: Selection, otherSelection: Selection))
--- @field intersect (fun(self: Selection, rectangle: Rectangle))|(fun(self: Selection, otherSelection: Selection))
--- @field contains (fun(self: Selection, point: Point): boolean)|(fun(self: Selection, x: number, y: number): boolean)

--- @class Tileset: table
--- @field name string
--- @field grid unknown
--- @field baseIndex number
--- @field color Color
--- @field data string
--- @field properties table
--- @field tile fun(self: Tileset, index: number): Tile
--- @field getTile fun(self: Tileset, index: number): Image

--- @class Tile: table
--- @field index number
--- @field image Image
--- @field color Color
--- @field data string
--- @field properties table

--- @class ColorSpace: table
--- @field name string

--- @class Tag: table
--- @field sprite Sprite
--- @field fromFrame Frame
--- @field toFrame Frame
--- @field frames number
--- @field name string
--- @field aniDir AniDir
--- @field color Color
--- @field repeats number
--- @field data string
--- @field properties table

--- @class Slice: table
--- @field bounds Rectangle
--- @field center Rectangle
--- @field color Color
--- @field data string
--- @field properties table
--- @field name string
--- @field pivot Point
--- @field sprite Sprite

--- @class Palette: table
--- @field resize fun(self: Palette, colors: number)
--- @field getColor fun(self: Palette, index: number): Color
--- @field setColor fun(self: Palette, index: number, color: Color)
--- @field frame Frame
--- @field saveAs fun(self: Palette, filename: string)

--- @class GraphicsContext: table
--- @field width number
--- @field height number
--- @field antialias boolean
--- @field color Color
--- @field strokeWidth number
--- @field blendMode BlendMode
--- @field opacity number
--- @field theme app.theme
--- @field save fun(self: GraphicsContext)
--- @field restore fun(self: GraphicsContext)
--- @field clip fun(self: GraphicsContext)
--- @field strokeRect fun(self: GraphicsContext, rectangle: Rectangle)
--- @field fillRect fun(self: GraphicsContext, rectangle: Rectangle)
--- @field fillText fun(self: GraphicsContext, text: string, x: number, y: number)
--- @field measureText fun(self: GraphicsContext, text: string): Size
--- @field drawImage (fun(self: GraphicsContext, image: Image, x: number, y: number))|(fun(self: GraphicsContext, image: Image, srcRect: Rectangle, dstRect: Rectangle))|(fun(self: GraphicsContext, image: Image, srcX: number, srcY: number, srcWidth: number, srcHeight: number, dstX: number, dstY: number, dstWidth: number, dstHeight: number))
--- @field drawThemeImage (fun(self: GraphicsContext, partId: string, x: number, y: number))|(fun(self: GraphicsContext, partId: string, point: Point))
--- @field drawThemeRect (fun(self: GraphicsContext, partId: string, rectangle: Rectangle))|(fun(self: GraphicsContext, partId: string, x: number, y: number, width: number, height: number))
--- @field beginPath fun(self: GraphicsContext)
--- @field closePath fun(self: GraphicsContext)
--- @field moveTo fun(self: GraphicsContext, x: number, y: number)
--- @field lineTo fun(self: GraphicsContext, x: number, y: number)
--- @field cubicTo fun(self: GraphicsContext, cx1: number, cy1: number, cx2: number, cy2: number, x: number, y: number)
--- @field oval fun(self: GraphicsContext, rectangle: Rectangle)
--- @field rect fun(self: GraphicsContext, rectangle: Rectangle)
--- @field roundedRect (fun(self: GraphicsContext, rectangle: Rectangle, radius: number))|(fun(self: GraphicsContext, rectangle: Rectangle, radiusX: number, radiusY: number))
--- @field stroke fun(self: GraphicsContext)
--- @field fill fun(self: GraphicsContext)

--- @class MouseEvent
--- @field x number
--- @field y number
--- @field button MouseButton
--- @field pressure unknown
--- @field deltaX? number
--- @field deltaY? number
--- @field altKey boolean
--- @field metaKey boolean
--- @field ctrlKey boolean
--- @field shiftKey boolean
--- @field spaceKey boolean

--- @alias PixelColor number

--- @class MouseButton
--- @field LEFT number
--- @field MIDDLE number
--- @field RIGHT number
--- @field X1 number
--- @field X2 number

--- @alias ColorMode
---| 0
---| 1
---| 2
---| 3

--- @alias BlendMode
---| 0
---| 1
---| 2
---| 3
---| 4
---| 5
---| 6
---| 7
---| 8
---| 9
---| 10
---| 11
---| 12
---| 13
---| 14
---| 15
---| 16
---| 17
---| 18
---| 19

--- @alias AniDir
---| 0
---| 1
---| 2
---| 3
