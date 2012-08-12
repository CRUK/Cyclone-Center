Spine = require 'spine'
CycloneSubject = require '../models/cyclone_subject'
Map = require 'Zooniverse/lib/map'
Dialog = require 'Zooniverse/lib/dialog'
StatsDialog = require './stats_dialog'

# Only temporary!
class Classification
  constructor: ({subjectId}) ->
    @values = {subjectId}
    @emitter = $({})

  annotate: (keyVal) =>
    for key, val of keyVal
      @values[key] = val
      @emitter.trigger "change", [key, val]

  get: (key) =>
    @values[key]

  onChange: (callback) ->
    @emitter.on 'change', (e, key, val) ->
      callback key, val

# Sizes for use in animations
NORMAL_SIZE = 250
PRO_SIZE = 485

OFF_LEFT = -250
NORMAL_LEFT = 20
PRO_LEFT = 30

OFF_RIGHT = 550
NORMAL_RIGHT = 280
PRO_RIGHT = 150

class Classifier extends Spine.Controller
  events:
    'mousedown .main-pair .subject': 'onMouseDownSubject'

    'click button[name="stronger"]': 'onClickButton'
    'click button[name="category"]': 'onClickButton'
    'click button[name="match"]': 'onClickButton'
    'click button[name="surrounding"]': 'onClickButton'
    'click button[name="exceeding"]': 'onClickButton'
    'click button[name="feature"]': 'onClickButton'
    'click button[name="blue"]': 'onClickButton'

    'click button[name="pro-classify"]': 'onClickProClassify'
    'click button[name="continue"]': 'onClickContinue'
    'click button[name="next-subject"]': 'onClickNext'

  elements:
    '.main-pair .previous': 'previousImage'
    '.main-pair .subject': 'subjectImage'
    '.main-pair .match': 'matchImage'
    '.center.point': 'centerPoint'
    '.red.point': 'redPoint'

    'button[name="stronger"]': 'strongerButtons'
    'button[name="category"]': 'categoryButtons'
    '.matches': 'matchListsContainer'
    '.matches > p': 'matchLists'
    'button[name="match"]': 'matchButtons'
    'button[name="surrounding"]': 'surroundingButtons'
    'button[name="exceeding"]': 'exceedingButtons'
    'button[name="feature"]': 'featureButtons'
    'button[name="blue"]': 'blueButtons'

    '.footer .progress .series .fill': 'seriesProgressFill'

    '.reveal .storm': 'storm'

    'button[name="pro-classify"]': 'proClassifyButton'
    'button[name="continue"]': 'continueButton'
    'button[name="next-subject"]': 'nextButton'

  map: null
  labels: null # Labelled points on the map

  defaultImageSrc: ''

  previousSubject: null

  nextSetup: null

  constructor: ->
    super

    @el.attr tabindex: 0 # Make this focusable.

    @map ?= new Map
      apiKey: '21a5504123984624a5e1a856fc00e238'
      latitude: 33
      longitude: -60
      zoom: 5
      className: 'full-screen'

    @map.el.prependTo @el.parent() # Is it a little sloppy to modify outside nodes?

    @labels ?= []

    @defaultImageSrc = @matchImage.attr 'src'
    @nextSubjects()

    doc = $(document)
    doc.on 'mousemove', @onMouseMoveDocument
    doc.on 'mouseup', @onMouseUpDocument

  nextSubjects: =>
    @previousSubject = CycloneSubject.current
    CycloneSubject.next (subject) =>
      @onChangeSubjects subject

  onChangeSubjects: (subject) =>
    meta = subject.metadata
    @classification = new Classification subjectId: CycloneSubject.current.id
    @classification.onChange @render
    @render()

    availableSubjects = CycloneSubject.count()

    if availableSubjects is 6
      # We won't use any previous subject.
      @previousSubject = null

      # First subject in a set, so clear out old labels.
      @map.removeLabel label for label in @labels
      @labels.splice 0

    @labels.push @map.addLabel subject.coords..., subject.coords.join ', '
    setTimeout => @map.setCenter subject.coords..., center: [0.25, 0.5]

    @previousImage.attr src: @previousSubject?.location.standard
    @subjectImage.attr src: subject.location.standard

    index = 6 - availableSubjects
    remaining = availableSubjects - 1

    @seriesProgressFill.css width: "#{index / (remaining + index + 1) * 100}%"

    @storm.html "#{meta.type} #{meta.name} (#{meta.year})"

    if @previousSubject?
      @setupStronger()
    else
      @setupCatsAndMatches()

  render: (attribute, value) =>
    if attribute
      @["render#{attribute.charAt(0).toUpperCase() + attribute[1...]}"]? value
    else
      method() for name, method of @ when name.match /^render.+/

    @activateButtons()

  activateButtons: =>
    for button in @el.find '[data-requires-selection]'
      $(button).prop disabled: not @classification.get(@el.attr 'data-step')?

  setupStronger: =>
    @previousImage.css height: @subjectImage.height(), left: @subjectImage.css('left'), width: @subjectImage.width()
    @subjectImage.css left: OFF_RIGHT
    @matchImage.animate opacity: 0, =>
      @subjectImage.parent().animate height: NORMAL_SIZE
      @previousImage.animate height: NORMAL_SIZE, left: NORMAL_LEFT, width: NORMAL_SIZE
      @subjectImage.animate height: NORMAL_SIZE, left: NORMAL_RIGHT, width: NORMAL_SIZE

    @el.attr 'data-step': 'stronger'
    @nextSetup = @setupCatsAndMatches
    @activateButtons()

  renderStronger: (stronger) =>
    @strongerButtons.removeClass 'selected'

    if stronger?
      @strongerButtons.filter("[value='#{stronger}']").addClass 'selected'

  setupCatsAndMatches: =>
    @previousImage.animate left: OFF_LEFT, =>
      @subjectImage.parent().animate height: NORMAL_SIZE
      @subjectImage.animate height: NORMAL_SIZE, left: NORMAL_LEFT, width: NORMAL_SIZE
      @matchImage.css left: OFF_RIGHT, opacity: 1
      @matchImage.animate left: NORMAL_RIGHT
    @el.attr 'data-step': 'match'
    @nextSetup = null
    @activateButtons()

  renderCategory: (category) =>
    @categoryButtons.removeClass 'selected'
    @matchLists.removeClass 'selected'

    if category?
      @categoryButtons.filter("[value='#{category}']").addClass 'selected'

      matchList = @matchLists.filter "[data-category='#{category}']"
      matchList.addClass 'selected'

      oldHeight = @matchListsContainer.height()
      @matchListsContainer.css height: ''
      naturalHeight = @matchListsContainer.height()

      @matchListsContainer.css height: oldHeight
      @matchListsContainer.animate height: naturalHeight
    else
      @matchListsContainer.animate height: 0, =>

    setTimeout => @classification.annotate match: null

    # No pro-classify for "other" storms.
    if category is 'other'
      @proClassifyButton.css display: 'none'
    else
      @proClassifyButton.css display: ''

  renderMatch: (match) =>
    @matchImage.toggleClass 'selected', match?
    @matchButtons.removeClass 'selected'

    if match?
      @matchButtons.filter("[value='#{match}']").addClass 'selected'

      # TODO: Do this better.
      @matchImage.attr src: @matchButtons.filter(".selected").find('img').attr 'src'
    else
      @matchImage.attr src: @defaultImageSrc

  setupCenter: =>
    @subjectImage.animate height: PRO_SIZE, left: PRO_LEFT, width: PRO_SIZE
    @subjectImage.parent().animate height: PRO_SIZE
    @matchImage.animate left: PRO_RIGHT, opacity: 0

    @el.attr 'data-step': 'center'
    @nextSetup = switch @classification.get 'category'
      when 'eye' then @setupSurrounding
      when 'embedded' then @setupFeature
      when 'curved' then @setupBlue
      when 'shear' then @setupRed

    @activateButtons()

  renderCenter: (coords) =>
    if coords?
      imgOffset = @subjectImage.offset()
      parentOffset = @subjectImage.parent().offset()
      x = coords[0] * @subjectImage.width() + (imgOffset.left - parentOffset.left)
      y = coords[1] * @subjectImage.height() + (imgOffset.top - parentOffset.top)
      @centerPoint.css left: x, top: y
    else
      @centerPoint.css left: "-50%", top: "-50%"

  setupSurrounding: =>
    @el.attr 'data-step': 'surrounding'
    @nextSetup = @setupExceeding
    @activateButtons()

  renderSurrounding: (surrounding) =>
    @surroundingButtons.removeClass 'selected'

    if surrounding?
      @surroundingButtons.filter("[value='#{surrounding}']").addClass 'selected'

  setupExceeding: =>
    @el.attr 'data-step': 'exceeding'
    @nextSetup = @setupFeature
    @activateButtons()

  renderExceeding: (exceeding) =>
    @exceedingButtons.removeClass 'selected'

    if exceeding?
      @exceedingButtons.filter("[value='#{exceeding}']").addClass 'selected'

  setupFeature: =>
    @el.attr 'data-step': 'feature'
    @nextSetup = null
    @activateButtons()

  renderFeature: (feature) =>
    @featureButtons.removeClass 'selected'
    if feature?
      @featureButtons.filter("[value='#{feature}']").addClass 'selected'

  setupBlue: =>
    @el.attr 'data-step': 'blue'
    @activateButtons()

  renderBlue: (blue) =>
    @blueButtons.removeClass 'selected'
    if blue?
      @blueButtons.filter("[value='#{blue}']").addClass 'selected'

  setupRed: =>
    @el.attr 'data-step': 'red'
    @activateButtons()

  renderRed: (coords) =>
    if coords?
      imgOffset = @subjectImage.offset()
      parentOffset = @subjectImage.parent().offset()
      x = coords[0] * @subjectImage.width() + (imgOffset.left - parentOffset.left)
      y = coords[1] * @subjectImage.height() + (imgOffset.top - parentOffset.top)
      @redPoint.css left: x, top: y
    else
      @redPoint.css left: "-50%", top: "-50%"

  onMouseDownSubject: (e) =>
    @mouseDown = e
    @onDragSubject e

  onMouseMoveDocument: (e) =>
    @onDragSubject e if @mouseDown

  onDragSubject: (e) =>
    step = @el.attr 'data-step'
    return unless step in ['center', 'red']

    e.preventDefault()
    offset = @subjectImage.offset()
    x = Math.min Math.max((e.pageX - offset.left) / @subjectImage.width(), 0), 1
    y = Math.min Math.max((e.pageY - offset.top) / @subjectImage.height(), 0), 1

    annotation = {}
    annotation[step] = [x, y]
    @classification.annotate annotation

  onMouseUpDocument: =>
    delete @mouseDown

  onClickButton: ({currentTarget}) =>
    target = $(currentTarget)
    property = target.attr 'name'
    value = target.val()
    value = true if value is 'true'
    value = false if value is 'false'

    annotation = {}
    annotation[property] = value
    annotation[property] = null if value is @classification.get property

    @classification.annotate annotation

  setupReveal: =>
    @el.attr 'data-step': 'reveal'
    @seriesProgressFill.css width: '100%'
    @classification.annotate reveal: true # For the "next" button
    @activateButtons()

  onClickProClassify: =>
    @setupCenter()

  onClickContinue: (e) =>
    @nextSetup()

  onClickNext: =>
    console.info 'Classified', JSON.stringify @classification.values

    if CycloneSubject.count() is 1 and not @classification.get 'reveal'
      @setupReveal()
    else
      @nextSubjects()

module.exports = Classifier
