// BuildLight WebSocket client
// Replaces ActionCable with plain WebSocket

(function () {
  // Determine channel and ID from URL path
  let channel, ids;

  if (document.location.pathname.match(/^\/devices\//)) {
    ids = document.location.pathname.match(/^\/devices\/([^\/\?]*)/)[1].split(",");
    channel = "device";
  } else {
    let match = document.location.pathname.match(/^\/([^\/\?]*)/);
    ids = match ? match[1].split(",") : [""];
    channel = "colors";
  }

  ids.forEach(function (id) {
    if (id === "") {
      id = "*";
    }

    let protocol = document.location.protocol === "https:" ? "wss:" : "ws:";
    let wsUrl = protocol + "//" + document.location.host + "/ws?channel=" + encodeURIComponent(channel) + "&id=" + encodeURIComponent(id);

    function connect() {
      let ws = new WebSocket(wsUrl);

      ws.onopen = function () {
        console.log("BuildLight WebSocket connected");
      };

      ws.onmessage = function (event) {
        let data = JSON.parse(event.data);
        updateUI(data);
      };

      ws.onclose = function () {
        // Reconnect after 3 seconds
        setTimeout(connect, 3000);
      };

      ws.onerror = function () {
        ws.close();
      };
    }

    connect();
  });

  function updateUI(data) {
    let redCount = +data.colors.red;
    let favicon = redCount ? "/favicon-failing" : "/favicon-passing";

    if (redCount > 0) {
      document.body.setAttribute("data-failing", "");
      document.body.removeAttribute("data-passing");
      let count = document.getElementById("failing-count");
      if (count) {
        let message = redCount === 1
          ? redCount + " project is"
          : redCount + " projects are";
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

    let faviconEl = document.getElementById("favicon");
    if (faviconEl) {
      faviconEl.setAttribute("href", favicon + ".ico");
    }
  }
})();
