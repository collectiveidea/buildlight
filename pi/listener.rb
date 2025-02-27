#!/usr/local/bin/ruby

require "bundler/setup"
require "json"
require "action_cable_client"
require "sd_notify"

if ENV["NOTIFY_SOCKET"]
  $stdout.reopen "listener.log", "a"
  $stderr.reopen "listener.log", "a"
  $stdout.sync = true
  $stderr.sync = true
end

class StopLight
  RED_LED = "16"
  YELLOW_LED = "15"
  GREEN_LED = "14"
  HOST = "buildlight.collectiveidea.com"
  DEVICE_ID = "collectiveidea-office"

  @red = true
  @yellow = true
  @green = true
  @blink_state = true
  @running = true

  def self.startup
    export_pin(RED_LED)
    export_pin(YELLOW_LED)
    export_pin(GREEN_LED)

    trap_signals
    SdNotify.ready
    setup_watchdog
    start_client
  end

  def self.set_colors(colors)
    @red = colors["red"]
    @yellow = colors["yellow"]
    @green = colors["green"]
    start_light_thread
  end

  def self.write_colors
    write_color(RED_LED, @red)
    write_color(YELLOW_LED, @yellow && @blink_state)
    write_color(GREEN_LED, @green)
  end

  def self.write_color(pin, value)
    File.write("/sys/class/gpio/gpio#{pin}/value", value ? "1" : "0")
  end

  def self.export_pin(pin)
    File.write("/sys/class/gpio/export", pin) unless File.exist?("/sys/class/gpio/gpio#{pin}/value")
  end

  def self.start_light_thread
    return if @started_light_thread

    Thread.new do
      loop do
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        write_colors
        @blink_state = !@blink_state
        SdNotify.status("{red: #{@red}, yellow: #{@yellow}, green: #{@green}}")
        sleep Process.clock_gettime(Process::CLOCK_MONOTONIC) - start + 1
      end
    end
    @started_light_thread = true
  end

  def self.setup_watchdog
    return unless SdNotify.watchdog?

    usec = Integer(ENV["WATCHDOG_USEC"])

    sec_f = usec / 1_000_000.0
    # "It is recommended that a daemon sends a keep-alive notification message
    # to the service manager every half of the time returned here."
    ping_f = sec_f / 2

    Thread.new do
      puts "[#{Time.current}] Pinging systemd watchdog every #{ping_f.round(1)} sec"
      loop do
        sleep ping_f
        SdNotify.watchdog
      end
    end
  end

  def self.start_client
    params = {channel: "DeviceChannel", id: DEVICE_ID}
    headers = {"ORIGIN" => "https://#{HOST}"}
    EventMachine.run do
      client = ActionCableClient.new("wss://#{HOST}/cable", params, true, headers)
      client.connected { puts "[#{Time.current}] successfully connected." }
      client.received do |message|
        puts "[#{Time.current}] #{message["message"]["colors"]}"
        set_colors(message["message"]["colors"])
      end
      client.disconnected { restart }
    end
  end

  def self.trap_signals
    Signal.trap("SIGTERM") { shutdown }
    Signal.trap("SIGHUP") { shutdown }
    Signal.trap("SIGINT") { shutdown }
    Signal.trap("SIGUSR1") { restart }
    Signal.trap("SIGUSR2") { restart }
  end

  def self.shutdown
    SdNotify.stopping
    @running = false
    exit
  end

  def self.restart
    return unless @running

    puts "[#{Time.current}] restarting"
    SdNotify.reloading
    Kernel.exec(__FILE__)
  end
end

StopLight.startup
