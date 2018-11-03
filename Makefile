.PHONY: style build clean

kicad-viewer.js: kicad-viewer.coffee
	coffee --compile kicad-viewer.coffee

style: kicad-viewer.coffee
	coffeelint kicad-viewer.coffee

build: kicad-viewer.js

clean:
	rm kicad-viewer.js
