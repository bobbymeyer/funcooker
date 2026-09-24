# Apple Reminders on the Mac the app runs on, through lib/reminders/add.js.
# Only there: see MacScript.
module Reminders
  Error = MacScript::Error

  SCRIPT = Rails.root.join("lib/reminders/add.js")
  PERMISSION_HINT = "The first run asks macOS for access to Reminders: allow it, or turn it on in System Settings → Privacy & Security → Reminders (and Automation, for the process running the app)."

  extend self

  def available?
    MacScript.available?
  end

  def list_name
    ENV.fetch("REMINDERS_LIST", "Groceries")
  end

  # Where thaw reminders go: a to-do, not something to buy.
  def thaw_list_name
    ENV.fetch("REMINDERS_THAW_LIST", "Reminders")
  end

  # items: [{ title:, notes:, due: (optional ISO 8601 time) }]. Returns
  # { "list", "added", "skipped" }.
  def add(items, list: list_name)
    MacScript.run(SCRIPT, { list:, items: }, permission_hint: PERMISSION_HINT, what: "Reminders")
  end
end
