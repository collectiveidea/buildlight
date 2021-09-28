(function() {
  var id, ids, _i, _len;

  App.setColors = function(data) {
    var count, favicon, message, redCount;
    redCount = +data.colors.red;
    favicon = redCount ? "/favicon-failing" : "/favicon-passing";
    if (redCount > 0) {
      document.body.setAttribute("data-failing", "");
      document.body.removeAttribute("data-passing");
      count = document.getElementById("failing-count");
      if (redCount === 1) {
        message = "" + redCount + " project is";
      } else {
        message = "" + redCount + " projects are";
      }
      count.innerHTML = message;
    } else {
      document.body.removeAttribute("data-failing");
      document.body.setAttribute("data-passing", "");
    }
    if (data.colors.yellow) {
      document.body.setAttribute("data-building", "");
      favicon += "-building";
    } else {
      document.body.removeAttribute("data-building");
    }
    return document.getElementById("favicon").setAttribute("href", favicon + ".ico");
  };

  ids = document.location.pathname.match(/^\/([^\/\?]*)/)[1].split(",");

  for (_i = 0, _len = ids.length; _i < _len; _i++) {
    id = ids[_i];
    if (id === "") {
      id = "*";
    }
    App.colors = App.cable.subscriptions.create({
      channel: "ColorsChannel",
      id: id
    }, {
      received: App.setColors
    });
  }

}).call(this);
