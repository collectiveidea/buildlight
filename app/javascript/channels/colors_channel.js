import consumer from "channels/consumer"

let ids = document.location.pathname.match(/^\/([^\/\?]*)/)[1].split(",");
ids.forEach( function(id) {
  if (id === "") {
    id = "*";
  }

  consumer.subscriptions.create({channel: "ColorsChannel", id: id}, {
    connected() {
      // Called when the subscription is ready for use on the server
    },

    disconnected() {
      // Called when the subscription has been terminated by the server
    },

    received(data) {
      // Called when there's incoming data on the websocket for this channel
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
    }
  });
});
