App.setColors = (data) ->
  redCount = +data.colors.red
  favicon = if redCount then "failing" else "passing"

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
    favicon += "-building"
  else
    document.body.removeAttribute("data-building")

  document.getElementById("favicon").setAttribute "href", "/favicon-#{ favicon }.ico"

# See: https://www.regex101.com/r/pEUNZ1/1
ids = document.location.pathname.match(/^\/([^\/\?]*)/)[1].split(",")
for id in ids
  id = "*" if id == "" # fallback for all on root path
  App.colors = App.cable.subscriptions.create channel: "ColorsChannel", id: id,
     received: App.setColors
