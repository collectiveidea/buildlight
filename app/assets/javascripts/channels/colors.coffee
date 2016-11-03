App.setColors = (data) ->
  redCount = +data.colors.red
  if redCount > 0
    document.body.setAttribute("data-failing", "true")
    document.body.removeAttribute("data-passing")
    count = document.getElementById("failing-count")
    if redCount == 1
      message = "" + redCount + " project is"
    else
      message = "" + redCount + " projects are"
    count.innerHTML = message
  else
    document.body.removeAttribute("data-failing")
    document.body.setAttribute("data-passing", "true")


  if data.colors.yellow
    document.body.setAttribute("data-building")
  else
    document.body.removeAttribute("data-building")


# See: http://scriptular.com/#%5E%5C%2F(%5B%5E%5C%2F%5C%3F%5D*)%7C%7C%7C%7C%7C%7C%7C%7C%5B%22%2F%22%2C%22%2Ffoo%22%2C%22%2Ffoo%2Cbar%22%2C%22%2Ffoo%2Cbar%2Cbaz%22%2C%22%2Ffoo%2Fbad%22%2C%22%2Ffoo%3Fbad%22%5D
ids = document.location.pathname.match(/^\/([^\/\?]*)/)[1].split(",")
for id in ids
  id = "*" if id == "" # fallback for all on root path
  App.colors = App.cable.subscriptions.create channel: "ColorsChannel", id: id,
     received: App.setColors

