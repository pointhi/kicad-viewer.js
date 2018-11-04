###
BSD 3-Clause License

Copyright (c) 2018, Thomas Pointhuber
All rights reserved.

@see: https://github.com/pointhi/kicad-viewer.js/blob/master/LICENSE
###

mod_edit_colors = {
  "Fg":         "rgb(255, 255, 255)"
  "Bg":         "rgb(0, 0, 0)"
  "F.Cu":       "rgb(132, 0, 0)"
  "In1.Cu":     "rgb(194, 194, 0)"
  "In2.Cu":     "rgb(194, 0, 194)"
  "In3.Cu":     "rgb(194, 0, 0)"
  "In4.Cu":     "rgb(0, 132, 132)"
  "In5.Cu":     "rgb(0, 132, 0)"
  "In6.Cu":     "rgb(0, 0, 132)"
  "B.Cu":       "rgb(0, 132, 0)"
  "F.Adhes":    "rgb(132, 0, 132)"
  "B.Adhes":    "rgb(0, 0, 132)"
  "F.Paste":    "rgb(132, 0, 0)"
  "B.Paste":    "rgb(0, 194, 194)"
  "F.SilkS":    "rgb(0, 132, 132)"
  "B.SilkS":    "rgb(132, 0, 132)"
  "F.Mask":     "rgb(132, 0, 132)"
  "B.Mask":     "rgb(132, 132, 0)"
  "Dwgs.User":  "rgb(194, 194, 194)"
  "Cmts.User":  "rgb(0, 0, 132)"
  "Eco1.User":  "rgb(0, 132, 0)"
  "Eco2.user":  "rgb(194, 194, 0)"
  "Egde.Cuts":  "rgb(194, 194, 0)"
  "Margin":     "rgb(194, 0, 194)"
  "F.CrtYd":    "rgb(194, 194, 194)"
  "B.CrtYd":    "rgb(132, 132, 132)"
  "F.Fab":      "rgb(132, 132, 132)"
  "B.Fab":      "rgb(0, 0, 132)"
}

color = mod_edit_colors

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

    key = null
    values = []
    while @la != ')'
      if @la == null
        throw new Error("')' expected, but EOF reached")
      else if @la == '('
        values.push this.parse_expr()
      else
        if key == null
          key = @la
        else
          values.push @la
        this.scan()

    this.scan()
    return {'k': key, 'v': values}


# Our Viewer which shows renders the given KiCad sexpr
class KiCadViewer
  constructor: (@canvas, @footprint) ->
    @ctx = @canvas.getContext '2d'
    @grid_spacing = 1 # mm
    @grid_width = 0.01 # mm

    # TODO: calculate bounding box of footprint
    @position = [290, 100]
    @scale = 18

  draw: ->
    # set our transformations
    @ctx.translate(@position[0],@position[1])
    @ctx.scale(@scale, @scale)

    # draw canvas
    this.draw_background()
    this.draw_footprint(@footprint.parsed.v)

  draw_background: ->
    # main background
    @ctx.fillStyle = color['Bg']
    start_x = -@position[0]/@scale
    start_y = -@position[1]/@scale
    width = @canvas.width/@scale
    height = @canvas.height/@scale
    @ctx.fillRect start_x, start_y, width, height

    # draw grid
    from_x = start_x - (start_x % @grid_spacing) - @grid_spacing
    from_y = start_y - (start_y % @grid_spacing) - @grid_spacing
    to_x = from_x + width + @grid_spacing
    to_y = from_y + height + @grid_spacing
    @ctx.strokeStyle = color['Fg']
    @ctx.lineWidth = @grid_width
    @ctx.beginPath()
    for x in [from_x...to_x] by @grid_spacing
      @ctx.moveTo(x, from_y)
      @ctx.lineTo(x, to_y)
    for y in [from_y...to_y] by @grid_spacing
      @ctx.moveTo(from_x, y)
      @ctx.lineTo(to_x, y)
    @ctx.stroke()

  draw_footprint: (kicad_fp) ->
    for elem in kicad_fp
      if elem.length == 0
        continue

      switch elem.k
        when 'layer' then continue
        when 'tedit' then continue
        when 'descr' then continue
        when 'tags' then continue
        when 'model' then continue
        when 'fp_line' then this.draw_fp_line(elem.v)
        when 'fp_text' then this.draw_fp_text(elem.v)
        else
          console.warn("unknow type:", elem.k)

  draw_fp_line: (elem) ->
    start = (elem.filter (e) -> e.k == 'start')[0].v
    end = (elem.filter (e) -> e.k == 'end')[0].v
    layer = (elem.filter (e) -> e.k == 'layer')[0].v
    width = (elem.filter (e) -> e.k == 'width')[0].v

    @ctx.strokeStyle = color[layer[0]]

    @ctx.lineCap = "round"
    @ctx.lineWidth = width[0]
    @ctx.beginPath()
    @ctx.moveTo(start[0], start[1])
    @ctx.lineTo(end[0], end[1])
    @ctx.stroke()

  draw_fp_text: (elem) ->
    console.log(elem)
    text = elem[1]
    layer = (elem.filter (e) -> e.k == 'layer')[0].v
    at = (elem.filter (e) -> e.k == 'at')[0].v

    @ctx.fillStyle = color[layer[0]]

    @ctx.font = "1.5px Courier"  # TODO: rounding errors of some charactes with other fonts
    @ctx.textAlign="center"
    @ctx.fillText(text, at[0],at[1])


# get all DOM elements which child is "kicad". For now only use data inline into the HTML as input
@entities = []
for canvas in document.getElementsByClassName 'kicad'
  sexpr = new SexprParser canvas.innerHTML
  @entities.push(new KiCadViewer canvas, sexpr)

# render every KiCad View a single time
@entities.forEach (e) -> e.draw()
