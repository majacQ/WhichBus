String.prototype.endsWith = (suffix) ->
  this.indexOf(suffix, this.length - suffix.length) != -1

window.defaultValue = (value, defaultValue) ->
  if value? then value else defaultValue

# HTML GENERATORS (jQuery wrappers)
window.tag = (tagname, classes, body...) ->
  html = $(tagname).addClass(classes)
  html.append text for text in body
  html
window.div = (classes, body...) ->
  tag "<div>", classes, body...
window.span = (classes, body...) ->
  tag "<span>", classes, body...
window.li = (classes, body...) ->
  tag "<li>", classes, body...
window.link = (href, classes, body...) ->
  tag("<a>", classes, body...).attr("href", href)

window.colorizeTime = (time) ->
  if time < 0 then "gone"
  else if time < 6 then "now"
  else if time < 16 then "soon"
  else if time < 36 then "soonish"
  else "later"

window.colorizeStatus = (status) ->
  if status.indexOf("early") > -1 then "early"
  else if status.indexOf("late") > -1 then "late"
  else ""

# abbreviates a string if it is above a certain length, optionally applying classes to the returned span
abbrevs = 0 # counter for abbreviation ID
window.abbreviate = (text, length, classes) ->
  return unless text? # gracefully handle null case
  if text.length > length
    # put the truncated text in a span with a tooltip containing the full text
    span("has-tip bottom #{classes}", "#{text[0..length]}...").attr("title", text).attr("id", "abbrev#{abbrevs++}")
  else span classes, text

# returns a distance string using miles if > 1000ft, otherwise in feet.
window.milesOrFeet = (distance) ->
  if distance < 0.19 then "#{(distance * 5280).toFixed(0)}ft" else "#{distance.toFixed(2)}mi"

# creates a stop display list item
window.stopDisplay = (stop) ->
  display = li "row display journey", link("/stop/#{stop.id}", "journey description", abbreviate(stop.name, 30)), span("journey time", milesOrFeet(stop.distance))

# creates an arrival display list item
window.arrivalDisplay = (arrival) ->
  journeyDisplayOptions
      route: link("/route/#{arrival.routeId}", "button radius whichbus-green", arrival.routeShortName)
      description: [
        tag("<small>", "headsign border round", arrival.tripHeadsign)
        "<br/>"
        abbreviate(arrival.description, 30)
      ]
      time: [
        div("row small", arrival.arrival)
        div("row #{colorizeTime(arrival.wait_minutes)}", arrival.wait_time)
        div("row small #{colorizeStatus(arrival.status)}", arrival.status)
      ]

# makes a button link for a route. automatically adds EXPRESS as needed.
window.routeLink = (routeName, routeId) ->
  if routeName.endsWith("E")
    link "route/#{routeId}", "", tag("<div>", "button radius whichbus-green", routeName.substr(0, routeName.length - 1), "<br/>", tag "<small>", "", "EXPRESS")
  else
    link "route/#{routeId}", "button radius whichbus-green", routeName

# displays an entire journey. creates markers and polyline for the stops and returns journey display HTML
window.journeyDisplay = (journey) ->
  # markers for from and to stops and a polyline connecting them
  @from_stop = markerOptions
      title: journey[0].name
      position: latlng(journey[0].lat, journey[0].lon)
      icon: "assets/busstop.png"
  to_stop = markerOptions
      title: journey[3].name
      position: latlng(journey[3].lat, journey[3].lon)
      icon: "assets/busstop.png"
  polylineOptions
    path: [from_stop.position, to_stop.position]
    strokeColor: "#7e8073"
    strokeOpacity: 0.5
  # build the journey display itself. lots of messy HTML generation
  journeyDisplayOptions
      route: routeLink(journey[2].routeShortName, journey[2].routeId)
      description: link ["stop/#{journey[0].id}", "", abbreviate(journey[0].name, 24, "from"),
        tag("<small>", "", " (#{milesOrFeet(journey[0].distance)})"), "<br/>"
        tag("<small>", "headsign border round", journey[2].tripHeadsign), "<br/>"
        abbreviate(journey[3].name, 24, "to"), tag("<small>", "", " (#{milesOrFeet(journey[3].distance)})")]...
      time: [
        div("row small", journey[2].arrival)
        div("row #{colorizeTime(journey[2].wait_minutes)}", journey[2].wait_time)
        div("row small #{colorizeStatus(journey[2].status)}", journey[2].status)
      ]

# constructs a journey list item with an error message
window.journeyDisplayError = (message) ->
  journeyDisplayOptions
      route: link("#", "button radius red", ":(")
      description: [
        tag("<small>", "headsign border round", "BAD NEWS ALL UP IN HERE")
        "<br/>#{message} Sorry, friend."
      ]
      time: ""

# constructs a journey list item. options: {route, description, time}
window.journeyDisplayOptions = (options) ->
  route = span "journey route", options.route...
  description = span "journey description", options.description...
  time = span "journey time", options.time...
  li "", div "row journey", route, description, time
