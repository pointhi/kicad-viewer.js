# Scanner for Sexpr parser
class SexprScanner
  constructor: (@raw) ->
    @index = 0 # index of current character
    @ch = '' # current character
    this.next_ch()

  next_ch: ->
    if @index < @raw.length
      @ch = @raw[@index]
      @index += 1
    else
      @ch = null # EOF reached

  is_whitespace: (ch) ->
    return ch in [' ', '\t', '\r', '\n']

  is_control: (ch) ->
    return ch in ['(', ')']

  parse_string: () ->
    string = ""
    this.next_ch()
    while @ch != null && @ch != '"'
      # TODO: escaping
      string += @ch
      this.next_ch()
    if @ch != '"'
      throw new new Error("'\"' expected")
    this.next_ch()
    return string

  next: ->
    # skip whitespaces
    while this.is_whitespace(@ch)
      this.next_ch()

    switch @ch
      when null then return null # EOF reached
      when '(' then this.next_ch(); return '('
      when ')' then this.next_ch(); return ')'
      when '"' then return this.parse_string()
      else
        # parse token
        token = ""
        while @ch != null && not this.is_whitespace(@ch) && not this.is_control(@ch)
          token += @ch
          this.next_ch()
        # TODO: format to int/float if applicable
        return token


# Parse sexpr into nested arrays for easier processing
class SexprParser
  constructor: (raw) ->
    @scanner = new SexprScanner raw

    # We build an LL1 parser
    @t = null # Current token
    @la = null # Look ahead token
    this.scan()

    # Parse our sexpr file
    @parsed = this.parse()
    console.log(@parsed)

  scan: ->
    @t = @la
    @la = @scanner.next()

  check: (token) ->
    if @la == token
      this.scan()
    else
      throw new Error("invalid token, '" + String(token) + "' expected but '" + @la + "' was found")

  parse: ->
    list = this.parse_expr()
    this.check(null)
    return list

  parse_expr: ->
    # Expr := '(' { token | Expr } ')'.
    this.check('(')

    list = []
    while @la != ')'
      if @la == null
        throw new Error("')' expected, but EOF reached")
      else if @la == '('
        list.push this.parse_expr()
      else
        list.push @la
        this.scan()

    this.scan()
    return list


# Our Viewer which shows renders the given KiCad sexpr
class KiCadViewer
  constructor: (@canvas, @sexpr) ->
    @ctx = @canvas.getContext '2d'
    @grid_spacing = 10 # mm
    @grid_width = 0.1 # mm

  draw: ->
    # TODO: depending on footprint size
    @ctx.scale(5, 5)

    this.draw_background()
    this.draw_layers()

  draw_background: ->
    # main background color
    @ctx.fillStyle = 'rgba(0,0,0,1)'
    @ctx.fillRect 0,0, @canvas.width, @canvas.height

    # draw grid
    @ctx.strokeStyle = 'rgba(255,255,255,1)'
    @ctx.lineWidth = @grid_width
    @ctx.beginPath()
    # TODO: use bounding-box of visible area in canvas
    for x in [0...@canvas.width] by @grid_spacing
      @ctx.moveTo(x, 0)
      @ctx.lineTo(x, @canvas.height)
    for y in [0...@canvas.height] by @grid_spacing
      @ctx.moveTo(0, y)
      @ctx.lineTo(@canvas.width, y)
    @ctx.stroke()

  draw_layers: ->
    # TODO: implement sexpr render
    @ctx.fillStyle = 'rgba(255,255,255,1)'
    @ctx.font = "20px Arial"
    @ctx.fillText("TODO",10,50)


# get all DOM elements which child is "kicad". For now only use data inline into the HTML as input
@entities = []
for canvas in document.getElementsByClassName 'kicad'
  sexpr = new SexprParser canvas.innerHTML
  @entities.push(new KiCadViewer canvas, sexpr)

# render every KiCad View a single time
@entities.forEach (e) -> e.draw()