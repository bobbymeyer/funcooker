require "open3"

# Runs one of the app's JavaScript for Automation scripts (lib/reminders,
# lib/calendar) with osascript, on the Mac the app runs on. Only there: a
# server in a container, or on anything but macOS, has no osascript, and says
# so.
module MacScript
  class Error < StandardError; end

  # Whether this is macOS, where osascript is, and what runs it: each
  # swappable, for tests.
  mattr_accessor :mac, default: -> { RUBY_PLATFORM.include?("darwin") }
  mattr_accessor :osascript, default: -> { ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, "osascript") }.find { |path| File.executable?(path) } }
  mattr_accessor :runner, default: ->(*command) { Open3.capture3(*command) }

  extend self

  def available?
    mac.call && osascript.call.present?
  end

  # Runs the script with the payload as JSON and returns what it printed,
  # parsed. A failure raises with the script's error and, when macOS refused
  # access, the hint for where to grant it.
  def run(script, payload, permission_hint:, what:)
    raise Error, "#{what} can only be reached from the Mac itself; this server is not running on macOS" unless available?

    out, err, status = runner.call(osascript.call, "-l", "JavaScript", script.to_s, payload.to_json)
    unless status.success?
      message = err.to_s.strip.presence || "osascript exited with #{status.exitstatus}"
      message += ". #{permission_hint}" if message.match?(/not authori[sz]ed|access not granted|-1743|-10004|not allowed/i)
      raise Error, message
    end

    JSON.parse(out)
  end
end
