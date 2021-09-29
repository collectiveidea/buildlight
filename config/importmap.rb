# Use direct uploads for Active Storage (remember to import "@rails/activestorage" in your application.js)
# pin "@rails/activestorage", to: "activestorage.esm.js"

# Use node modules from a JavaScript CDN by running ./bin/importmap

pin "application"
pin "@rails/actioncable", to: "vendor/actioncable.esm.js"
pin_all_from "app/javascript/channels", under: "channels"
