allMarkers = new Array
namedMarkers = {}
nearbyMarkers = new Array

detectBrowser = () ->
  mapdiv = $("#map_canvas")
  mapdiv.css 'width', '100%'
  if 'iPhone' in navigator.userAgent or 'Android' in navigator.userAgent
    mapdiv.css 'height', '200px'
  else
    mapdiv.css 'height', '600px'
    
# rock some geolocation
yesLocation = (position) ->
  pos = latlng position.coords.latitude, position.coords.longitude
  @userPosition = markerOptions({title:"Your Location", position:pos})
  clickMap(pos)
noLocation = () ->
  msg = "Geolocation Error: "
  switch error.code
    when error.TIMEOUT
      msg += "Timeout"
    when error.POSITION_UNAVAILABLE
      msg += "Position unavailable"
    when error.PERMISSION_DENIED
      msg += "Permission denied"
    when error.UNKNOWN_ERROR
      msg += "Unknown error"
  alert(msg)
geolocate = (success=yesLocation, fail=noLocation) ->
  navigator.geolocation.getCurrentPosition success, fail
window.geolocate = geolocate  

# simplify Google Maps API
# creates a maps.LatLng with the given coordinates. easy!
latlng = (lat, lng) ->
  new google.maps.LatLng(lat, lng)
window.latlng = latlng

# creates a maps.Marker with the given title and position
# and adds it to the given marker group (an array of markers
marker = (title, position, group=null, handler=null) ->
  mrkr = new google.maps.Marker({map: @googleMap, position: position, title: title})
  google.maps.event.addListener(mrkr, 'click', handler) if handler?
  group.push(mrkr) if group?
  allMarkers.push(mrkr)
  mrkr
window.marker = marker

# a more versatile marker creator that takes a hash of options
# takes standard marker options + handler (click event handler), group (array of related markers)
markerOptions = (options) ->
  options.map = @googleMap  # add marker to the map object
  mrkr = new google.maps.Marker(options)  # create marker from options hash (extra options will be ignored)
  console.log "new marker #{options.title} at #{mrkr.position.lat()}, #{mrkr.position.lng()}"
  # register click listener to call the given event handler
  google.maps.event.addListener(mrkr, 'click', options.handler) if options.handler?
  options.group.push(mrkr) if options.group?
  allMarkers.push(mrkr)
  mrkr
window.markerOptions = markerOptions

# creates a polyline! takes standard polyline options
polyline = (options) ->
  options.map = @googleMap
  line = new google.maps.Polyline(options)
window.polylineOptions = polyline

# given an array of markers, removes all of them from the map and empties the array.
clearMarkerGroup = (group) ->
  if group?
    marker.setMap(null) for marker in group
    group.splice 0, group.length

clickMap = (position) ->
  google.maps.event.trigger(@googleMap, 'click', {latLng: position})
  @googleMap.setZoom(14) if @googleMap.zoom < 13

window.showStopMarker = (position) ->
  @clickMarker.setPosition(position)
  
# map click handlers
window.nothing = nothing = (event) ->;

# load stops near the given position and display markers and list
window.loadNearbyStops = (position) =>
  clearMarkerGroup nearbyMarkers
  @clickMarker.setPosition(position) 
  url = "/stop.json"
  list = $("#model-list")
  list.fadeOut 'fast'
  # perform an AJAX request to stop#index with the user's location
  $.get url, {lat: position.lat(), lon: position.lng(), api: yes}, (result) ->
    list.html ""
    # the API returns a JSON array of stops
    # iterate through the array and display each one in the list column and create a marker for it
    for stop in result
      list.append(stopDisplay(stop)).fadeIn()
      markerOptions
        title: stop.name
        position: latlng(stop.lat, stop.lon)
        icon: "/assets/busstop.png"
        group: nearbyMarkers
        handler: clickStopMarker(stop)

# load nearby stops with predictions and display the first one (closest to the user)
window.loadNearestStop = (position) ->
  url = "/stop.json"
  list = $("#model-list")
  title = $("#page-title-header")
  title.html("Finding Nearest Stop...")
  list.fadeOut 'fast'
  # create a marker at the query location
  markerOptions
    title: "Your Location"
    position: position
  $.get url, {lat: position.lat(), lon: position.lng(), predictions: true}, (result) ->
    list.html("").show()
    stop = result[0]  # the nearest stop (results sorted by distance)
    # set the page title
    title.fadeOut 'fast', -> title.html(stop.name).fadeIn()
    # create a marker for the nearest stop
    markerOptions
      title: stop.name
      position: latlng(stop.lat, stop.lon)
      icon: "/assets/busstop.png"
    # display all the upcoming arrivals
    for route in stop.routes when route.arrivals.length > 0
      for trip in route.arrivals
        list.append arrivalDisplay(trip).fadeIn()

# event handler for clicking on a stop marker
# returns an anonymous function to call when the stop is clicked on
clickStopMarker = (stop) -> () ->
  $("#page-title-header").text(stop.title)
  loadStopSchedule stop.id

# TODO: implement this filter parameter! it needs to come from somewhere, only Ruby knows about it
# load arrivals for the given stop and display in list
loadStopSchedule = (stopId, filter="") ->
  url = "/stop/#{stopId}/schedule.json"
  list = $("#model-list")
  list.fadeOut()
  $.get url, {api:yes, r: filter}, (result) =>
    list.html("").show()
    stop = result["stop"]
    pos = latlng(stop.lat, stop.lon)
    # center the map and add a marker for the stop
    @googleMap.setCenter(pos)
    markerOptions
      title: stop.name
      position: pos
      icon: "/assets/busstop.png"
    # display each of the arrivals
    if result["arrivals"].length == 0
      list.append journeyDisplayError "No upcoming arrivals."
    else
      for trip in result["arrivals"]
        list.append arrivalDisplay(trip).fadeIn()
    
    # loadNearbyStops(pos)
window.loadStopSchedule = loadStopSchedule

###
# JOURNEY METHODS
###
hereStrings = ["current location", "here", ""]  # whitelist of search terms that return user's current location
window.locationFound = (position) ->
  $("input#currentPosition").val("#{position.coords.latitude},#{position.coords.longitude}")
  alert "geocode success"
window.showJourney = (from, to, userPosition) ->
  # initialize the map using loadJourney and no click functionality
  @dataFunction = -> loadJourney(from, to)
  initializeMap(dataFunction, nothing)
  initializeMapOptions
    clickHandler: nothing
    geolocate:
      enable: true
      onSuccess: loadJourney(from, to)
      onFail: noLocation

# returns a geolocation callback that takes the user's position
loadJourney = (from, to) -> (position) ->
  title = $("#page-title-header")
  title.html("Loading directions from #{from} to #{to}...").fadeIn()
  # @dataFunction = -> loadJourney(from, to)(position) # TODO: set the dataFunction so we can refresh

  if position?
    userPosition = "#{position.coords.latitude},#{position.coords.longitude}"
    # update the query strings if the user asks for current location
    from = userPosition if from.toLowerCase() in hereStrings
    to = userPosition if to.toLowerCase() in hereStrings
  #alert "#{from} to #{to}"
  list = $("#model-list")
  list.fadeOut -> list.html("<p id=\"loading_spinner\"></p>").fadeIn()
  loadingSpinner()
  getJourney(from, to)

# call the options.json API to calculate the possible routes
window.getJourney = (from, to) ->
  $.get "/options.json", {
    from: if typeof(from) == "object" then from = from.toString() else from
    to:   if typeof(to) == "object" then to = to.toString() else to}, processJourneyResult

processJourneyResult = (result) =>
  title = $("#page-title-header")
  list = $("#model-list")
  list.html("").show()
  #returns three things: from, to, and trips
  from = result["from"]
  to = result["to"]
  # build title from the first two items
  title.fadeOut 'medium', ->
    title.html("<em>From:</em> ").append(from.name).append("<br>")
    title.append("<em>To:</em> ").append(to.name).fadeIn()
  # create markers for origin and destination, clear previous markers if they exist
  @fromMarker.setMap null if @fromMarker?
  @fromMarker = markerOptions
    title: from.name
    position: latlng(from.latitude, from.longitude)
    icon: "http://thydzik.com/thydzikGoogleMap/markerlink.php?text=A&color=FC6355"
    draggable: true # allow user to drag endpoints to recalculate journey
  @toMarker.setMap null if @toMarker?
  @toMarker = markerOptions
    title: to.name
    position: latlng(to.latitude, to.longitude)
    icon: "http://thydzik.com/thydzikGoogleMap/markerlink.php?text=B&color=FC6355"
    draggable: true
  # add event listeners for dragging start and end markers
  google.maps.event.addListener fromMarker, 'dragend', (mouse) ->
    line.setMap null
    getJourney(mouse.latLng, toMarker.position)
  google.maps.event.addListener toMarker, 'dragend', (mouse) ->
    line.setMap null
    getJourney(fromMarker.position, mouse.latLng)
  # construct a function to refresh the journeys (mostly to update times)
  @dataFunction = -> getJourney(fromMarker.position, toMarker.position)
  @googleMap.setCenter fromMarker.position
  # iterate through trips, adding journey row for each one
  if result["trips"].length == 0
    list.append journeyDisplayError "No connecting buses found."
  else
    for trip in result["trips"]
      list.append journeyDisplay(trip).fadeIn()
window.loadJourney = loadJourney

# calls the dataFunction if it is set
window.refreshData = () ->
  @dataFunction() if @dataFunction?

# THIS IS THE BIG ONE #
#######################
# Creates the Google Map object and some helper variables
# dataFunction() : calls dataFunction() to load some initial screen data
# clickHandler(latlng) : attaches clickhandler to the map's 'click' event
# doGeolocate:bool : indicates whether geolocation should be performed after the map is set up
#######################
initializeMap = (dataFunction, clickHandler, doGeolocate = true) ->
  initializeMapOptions
    clickHandler: clickHandler
    dataFunction: dataFunction
    geolocate: 
      enable: doGeolocate
      onSuccess: yesLocation
      onFail: noLocation
window.initializeMap = initializeMap
# but really, it takes an options hash that lets you set all sorts of things!
# { zoom:, mapType:, defaultPosition:, clickHandler:, dataFunction:, geolocate: { enable:, onSuccess:, onFail: } }
initializeMapOptions = (options) ->
  defaultPosition = defaultValue(options.defaultPosition, latlng(47.652709,-122.32149))
  mapOptions =
    zoom: defaultValue(options.zoom, 13)
    center: defaultPosition
    mapTypeId: defaultValue(options.mapType, google.maps.MapTypeId.ROADMAP)
    disableDefaultUI: true

  @googleMap = new google.maps.Map(document.getElementById("map_canvas"), mapOptions)
  # a marker showing where the user last clicked (generally the query point)
  @clickMarker = markerOptions({title:"Seattle", position:defaultPosition})
  # register click handler, wrapping it in a function to extract the latLng object
  if options.clickHandler?
    google.maps.event.addListener(@googleMap, 'click', (event) -> options.clickHandler event.latLng)
  # final stuff: perform geolocation, load initial data
  geolocate(options.geolocate.onSuccess, options.geolocate.onFail) if options.geolocate.enable
  @dataFunction = options.dataFunction
  refreshData()
  @googleMap  # return the map object
window.initializeMapOptions = initializeMapOptions
