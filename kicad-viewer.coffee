###
BSD 3-Clause License

Copyright (c) 2018, Thomas Pointhuber
All rights reserved.

@see: https://github.com/pointhi/kicad-viewer.js/blob/master/LICENSE
###

mod_edit_colors = {
  "Fg":         "rgb(255, 255, 255)"
  "Pads":       "rgb(0, 132, 0)"
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

        if /^-?\d+$/.test(token)
          return parseInt(token)

        if /^-?\d+(?:[.,]\d*?)?$/.test(token)
          return parseFloat(token)

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

sexpr_find_child = (elem, type) ->
  return (elem.filter (e) -> e.k == type)[0].v


# Our Viewer which shows renders the given KiCad sexpr
class KiCadViewer
  constructor: (@canvas, @footprint) ->
    @ctx = @canvas.getContext '2d'
    @grid_spacing = 1 # mm
    @grid_width = 0.01 # mm

    # TODO: calculate bounding box of footprint
    @position = [290, 100]
    @scale = 18

  get_ctx: (layer) ->
    # TODO: one context per layer
    @ctx.strokeStyle = color[layer]
    @ctx.fillStyle = color[layer]

    return @ctx

  draw: ->
    # store transformation matrix
    @ctx.save()

    # set our transformations
    @ctx.translate(@position[0],@position[1])
    @ctx.scale(@scale, @scale)

    # draw canvas
    this.draw_background()
    this.draw_footprint(@footprint.parsed.v)

    # restore transformation matrix
    @ctx.restore()

  draw_background: ->
    # main background
    start_x = -@position[0]/@scale
    start_y = -@position[1]/@scale
    width   = @canvas.width/@scale
    height  = @canvas.height/@scale
    this.get_ctx("Bg").fillRect start_x, start_y, width, height

    # draw grid
    from_x  = start_x - (start_x % @grid_spacing) - @grid_spacing
    from_y  = start_y - (start_y % @grid_spacing) - @grid_spacing
    to_x    = from_x + width + 2*@grid_spacing
    to_y    = from_y + height + 2*@grid_spacing
    grid_ctx = this.get_ctx("Fg")
    grid_ctx.lineWidth = @grid_width
    grid_ctx.beginPath()
    for x in [from_x...to_x] by @grid_spacing
      grid_ctx.moveTo(x, from_y)
      grid_ctx.lineTo(x, to_y)
    for y in [from_y...to_y] by @grid_spacing
      grid_ctx.moveTo(from_x, y)
      grid_ctx.lineTo(to_x, y)
    grid_ctx.stroke()

  draw_footprint: (kicad_fp) ->
    for elem in kicad_fp[1...]
      if elem.length == 0
        continue

      switch elem.k
        when 'layer'    then continue
        when 'tedit'    then continue
        when 'descr'    then continue
        when 'tags'     then continue
        when 'model'    then continue
        when 'fp_line'  then this.draw_fp_line(elem.v)
        when 'fp_text'  then this.draw_fp_text(elem.v)
        when 'pad'      then this.draw_pad(elem.v)
        else
          console.warn("unknow type:", elem.k)

  draw_fp_line: (elem) ->
    start = sexpr_find_child(elem, 'start')
    end   = sexpr_find_child(elem, 'end')
    layer = sexpr_find_child(elem, 'layer')[0]
    width = sexpr_find_child(elem, 'width')[0]

    ctx = this.get_ctx(layer)
    ctx.lineCap = "round"
    ctx.lineWidth = width

    ctx.beginPath()
    ctx.moveTo(start[0], start[1])
    ctx.lineTo(end[0], end[1])
    ctx.stroke()

  draw_fp_text: (elem) ->
    text    = elem[1]
    childs  = elem[2...]
    at      = sexpr_find_child(childs, 'at')
    layer   = sexpr_find_child(childs, 'layer')[0]

    ctx = this.get_ctx(layer)
    ctx.font = "1.5px Courier"  # TODO: rounding errors of some charactes with other fonts
    ctx.textAlign="center"

    ctx.fillText(text, at[0],at[1])

  draw_pad: (elem) ->
    number  = elem[0]
    type    = elem[1]
    shape   = elem[2]
    childs  = elem[3...]
    at      = sexpr_find_child(childs, 'at')
    size    = sexpr_find_child(childs, 'size')
    layers  = sexpr_find_child(childs, 'layers')
    drill   = sexpr_find_child(childs, 'drill')

    ctx = this.get_ctx('Pads')

    switch shape
      when 'oval'
        @ctx.beginPath()
        @ctx.arc(at[0], at[1], size[1]/2, 0, 2*Math.PI, false)
        # TODO actually handle non circle ovals
      when 'rect'
        @ctx.beginPath()
        @ctx.rect(at[0]-size[0]/2, at[1]-size[1]/2, size[0], size[1], false)
      else
        console.warn("unknow shape:", shape)

    if drill
      @ctx.arc(at[0], at[1], drill/2, 0, 2*Math.PI, true)

    @ctx.fill('evenodd')

  make_interactive: ->
    @is_dragging = false  # TODO: use current mouse state
    @last_pos = undefined

    this_obj = this

    @canvas.onmousedown = ->
      @is_dragging = true

    @canvas.onmouseup = ->
      @is_dragging = false

    @canvas.onmousemove = (event) ->
      cur_pos = {
        x: event.clientX
        y : event.clientY
      }

      if not @is_dragging
        @last_pos = cur_pos
        return

      if @last_pos == undefined
        @last_pos = cur_pos

      this_obj.position[0] -= @last_pos.x - cur_pos.x
      this_obj.position[1] -= @last_pos.y - cur_pos.y

      @last_pos = cur_pos
      this_obj.draw()

    mouse_scroll_func = (event) ->
      delta = event.delta #|| event.originalEvent.wheelDelta
      if delta == undefined
        delta = event.detail #we are on firefox

      if delta >= 0
        this_obj.scale *= 2/delta
      else
        this_obj.scale *= -delta/2

      # TODO: zoom to position of mouse pointer

      event.preventDefault()
      this_obj.draw()

    @canvas.onmousewheel = mouse_scroll_func  # general
    @canvas.addEventListener('DOMMouseScroll', mouse_scroll_func, false)  # Firefox specific


# get all DOM elements which child is "kicad". For now only use data inline into the HTML as input
@entities = []
for canvas in document.getElementsByClassName 'kicad'
  sexpr = new SexprParser canvas.innerHTML
  @entities.push(new KiCadViewer canvas, sexpr)

# render every KiCad View a single time
@entities.forEach (e) -> e.draw()

# make canvas interactive
@entities.forEach (e) -> e.make_interactive()
