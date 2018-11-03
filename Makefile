.PHONY: style clean

kicad-viewer.js: kicad-viewer.coffee
	coffee --compile kicad-viewer.coffee

style: kicad-viewer.coffee
	coffeelint kicad-viewer.coffee

clean:
	rm kicad-viewer.js
