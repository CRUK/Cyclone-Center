Dialog = require 'zooniverse/lib/dialog'
Map  = require 'zooniverse/lib/map'
BarGraph  = require 'zooniverse/lib/bar_graph'

template = require 'views/stats_dialog'

class StatsDialog extends Dialog
  storm: null

  constructor: ->
    super

    @storm ?= # For dev!
      type: 'Hurricane'
      name: 'Brian'
      start: (new Date).getMonth()
      end: (new Date).getMonth()
      scale: 'Saffir-Simpson'
      strength: 'Category 5'
      captures: [0...50]
      coords: ([
        +(Math.random() * 5 + 20).toString().slice 0, 7
        +(Math.random() * -10 - 60).toString().slice 0, 7
      ] for i in [0...50])
      windSpeeds: ((Math.random() * 150) for i in [0...50])
      pressures: ((Math.random() * 60) + 900 for i in [0...50])

    @content = 'Loading stats...'

    @el.addClass 'stats'
    @content = template @storm

  render: =>
    super

    @map = new Map
      el: @el.find '.path .map'

    allLats = []
    allLngs = []
    @storm.coords.forEach (coords) =>
      @map.addLabel coords..., ''
      allLats.push coords[0]
      allLngs.push coords[1]
      zoom: 3

    avgCoords = [
      (1 / allLats.length) * allLats.reduce (a, b) -> a + b
      (1 / allLngs.length) * allLngs.reduce (a, b) -> a + b
    ]

    @map.setCenter avgCoords...

    @windSpeedGraph = new BarGraph
      el: @el.find '.wind-speed .graph'
      x: 'Date': @storm.captures
      y: 'kt': @storm.windSpeeds

    @pressureGraph = new BarGraph
      el: @el.find '.pressure .graph'
      x: 'Date': @storm.captures
      y: 'mb': @storm.pressures
      floor: Math.floor 0.95 * Math.min @storm.pressures...

  open: =>
    super
    setTimeout =>
      @map.resize()
      @map.setZoom @map.zoom


module.exports = StatsDialog
