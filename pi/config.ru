require "bundler/setup"

require "net/http"
require "json"

class StopLight
  RED_LED = "16"
  GREEN_LED = "14"
  YELLOW_LED = "15"

  def self.startup
    File.write("/sys/class/gpio/export", RED_LED) unless File.exist?("/sys/class/gpio/gpio#{RED_LED}/value")
    File.write("/sys/class/gpio/export", GREEN_LED) unless File.exist?("/sys/class/gpio/gpio#{GREEN_LED}/value")
    File.write("/sys/class/gpio/export", YELLOW_LED) unless File.exist?("/sys/class/gpio/gpio#{YELLOW_LED}/value")

    sleep 1

    set_color(RED_LED, "1")
    set_color(GREEN_LED, "1")
    set_color(YELLOW_LED, "1")

    sleep 1

    set_color(RED_LED, "0")
    set_color(GREEN_LED, "0")
    set_color(YELLOW_LED, "0")
  end

  def self.set_colors(colors)
    set_color(RED_LED, colors["red"] ? "1" : "0")
    set_color(GREEN_LED, colors["green"] ? "1" : "0")
    set_color(YELLOW_LED, colors["yellow"] ? "1" : "0")
  end

  def self.set_color(pin, value)
    File.write("/sys/class/gpio/gpio#{pin}/value", value)
  end
end

StopLight.startup

run do |env|
  req = Rack::Request.new(env)
  case req.path
  when "/set-colors"
    colors = JSON.parse(req.body.read)["colors"]
    StopLight.set_colors(colors)
    [200, {}, ["OK"]]
  else
    [404, {}, ["Not Found"]]
  end
end
