$ = require 'jqueryify'
Subject = require 'zooniverse/lib/models/subject'
config = require '../lib/config'
Api = require 'zooniverse/lib/api'

randomPropertyFrom = (object) ->
  keys = Object.keys object
  object[keys[Math.floor Math.random() * keys.length]]

class CycloneSubject extends Subject
  @configure 'CycloneSubject', 'zooniverse_id', 'coords', 'location', 'metadata'

  @current: null

  @next: (callback) =>
    @current.destroy() if @current

    fetcher = if @count() is 0
      @fetch()
    else
      d = new $.Deferred
      d.resolve @all()
      d.promise()

    nexter = fetcher.pipe =>
      @current = @first()
      @current

    nexter.then callback

    nexter

  @fetch: (count = config.setSize) =>
    fetcher = $.Deferred()

    Api.get "/projects/cyclone_center/groups/subjects", (rawSubjects) =>
      newSubjects = @fromJSON rawSubject for rawSubject in rawSubjects
      fetcher.resolve newSubjects

    fetcher.promise()

  @fromJSON: (raw) =>
    @create
      location: standard: randomPropertyFrom raw.location
      coords: [raw.metadata.map_lat, raw.metadata.map_lng]
      metadata: raw.metadata

module.exports = CycloneSubject
