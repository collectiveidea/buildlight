$ ->
  updateStatus()

toggleLight = (color, lighted) ->
  if lighted
    $("#buildlight-"+color).addClass "lighted"
  else
    $("#buildlight-"+color).removeClass "lighted"

updateStatus = () ->
  $.get "panic.json", (data) ->
    for color of data
      toggleLight color, data[color]

  setTimeout updateStatus, 1000

window.toggleLight = toggleLight
