# Parse sexpr into nested arrays for easier processing
class SexprParser
  constructor: (@raw) ->
    @parsed = this.parse_sexpr()

  parse_sexpr: ->
    return []


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


# get all DOM elements which child is "kicad"
# for now only use data inline into the HTML as input
@entities = []
for canvas in document.getElementsByClassName 'kicad'
  sexpr = new SexprParser canvas.innerHTML
  @entities.push(new KiCadViewer canvas, sexpr)

# render every KiCad View a single time
@entities.forEach (e) -> e.draw()