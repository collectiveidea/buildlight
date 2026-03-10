// WebSocket client for Buildlight
(function() {
  var protocol = location.protocol === "https:" ? "wss:" : "ws:";
  var wsURL = protocol + "//" + location.host + "/ws";
  var ids, channelPrefix;

  if (document.location.pathname.match(/^\/devices\//)) {
    ids = document.location.pathname.match(/^\/devices\/([^\/\?]*)/)[1].split(",");
    channelPrefix = "device:";
  } else {
    ids = document.location.pathname.match(/^\/([^\/\?]*)/)[1].split(",");
    channelPrefix = "colors:";
  }

  function connect() {
    var ws = new WebSocket(wsURL);

    ws.onopen = function() {
      // Subscribe to channels
      ids.forEach(function(id) {
        if (id === "") id = "*";
        ws.send(JSON.stringify({ subscribe: channelPrefix + id }));
      });
    };

    ws.onmessage = function(event) {
      var msg = JSON.parse(event.data);
      var data = msg.data;
      if (!data || !data.colors) return;

      var redCount = +data.colors.red;
      var favicon = redCount ? "/public/favicon-failing" : "/public/favicon-passing";

      if (redCount > 0) {
        document.body.setAttribute("data-failing", "");
        document.body.removeAttribute("data-passing");
        var count = document.getElementById("failing-count");
        if (count) {
          var message;
          if (redCount === 1) {
            message = "" + redCount + " project is";
          } else {
            message = "" + redCount + " projects are";
          }
          count.textContent = message;
        }
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

      var faviconEl = document.getElementById("favicon");
      if (faviconEl) {
        faviconEl.setAttribute("href", favicon + ".ico");
      }
    };

    ws.onclose = function() {
      // Reconnect after 3 seconds
      setTimeout(connect, 3000);
    };

    ws.onerror = function() {
      ws.close();
    };
  }

  connect();
})();
