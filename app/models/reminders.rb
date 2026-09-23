require "open3"

# Apple Reminders on the Mac the app runs on, through lib/reminders/add.js.
# Only there: a server in a container, or on anything but macOS, has no
# Reminders to write to, and says so.
module Reminders
  class Error < StandardError; end

  SCRIPT = Rails.root.join("lib/reminders/add.js")
  PERMISSION_HINT = "The first run asks macOS for access to Reminders: allow it, or turn it on in System Settings → Privacy & Security → Reminders (and Automation, for the process running the app)."

  # Whether this is macOS, where osascript is, and what runs it: each
  # swappable, for tests.
  mattr_accessor :mac, default: -> { RUBY_PLATFORM.include?("darwin") }
  mattr_accessor :osascript, default: -> { ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, "osascript") }.find { |path| File.executable?(path) } }
  mattr_accessor :runner, default: ->(*command) { Open3.capture3(*command) }

  extend self

  def available?
    mac.call && osascript.call.present?
  end

  def list_name
    ENV.fetch("REMINDERS_LIST", "Groceries")
  end

  # items: [{ title:, notes: }]. Returns { "list", "added", "skipped" }.
  def add(items)
    raise Error, "Reminders can only be written from the Mac itself; this server is not running on macOS" unless available?

    out, err, status = runner.call(osascript.call, "-l", "JavaScript", SCRIPT.to_s, { list: list_name, items: }.to_json)
    unless status.success?
      message = err.to_s.strip.presence || "osascript exited with #{status.exitstatus}"
      message += ". #{PERMISSION_HINT}" if message.match?(/not authori[sz]ed|-1743|-10004|not allowed/i)
      raise Error, message
    end

    JSON.parse(out)
  end
end
