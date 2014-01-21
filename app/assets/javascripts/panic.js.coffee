$ ->
  setTimeout updateStatus, 30000

updateStatus = () ->
  $.get "panic.json", (data) ->
    for color of data
      if data[color]
        $("."+color).addClass "lighted"
      else
        $("."+color).removeClass "lighted"

  setTimeout updateStatus, 30000
