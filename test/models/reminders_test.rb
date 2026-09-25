require "test_helper"

class RemindersTest < ActiveSupport::TestCase
  Status = Struct.new(:success?, :exitstatus)

  setup do
    @defaults = [ MacScript.mac, MacScript.osascript, MacScript.runner ]
    @calls = []
  end

  teardown do
    MacScript.mac, MacScript.osascript, MacScript.runner = @defaults
  end

  test "not available off macOS, and says so" do
    MacScript.mac = -> { false }

    assert_not Reminders.available?
    error = assert_raises(Reminders::Error) { Reminders.add([]) }
    assert_match "not running on macOS", error.message
  end

  test "runs the script with the list and its items" do
    on_a_mac replying: [ '{"list":"Groceries","added":2,"skipped":1}', "", Status.new(true, 0) ]

    result = Reminders.add([ { title: "corn tortilla, 3", notes: "for tacos" } ])

    assert_equal({ "list" => "Groceries", "added" => 2, "skipped" => 1 }, result)
    command = @calls.sole
    assert_equal [ "/usr/bin/osascript", "-l", "JavaScript", Reminders::SCRIPT.to_s ], command.first(4)
    assert_equal({ "list" => "Groceries", "items" => [ { "title" => "corn tortilla, 3", "notes" => "for tacos" } ] }, JSON.parse(command.last))
  end

  test "a refusal from macOS says what permission to give" do
    on_a_mac replying: [ "", "execution error: Not authorized to send Apple events to Reminders. (-1743)", Status.new(false, 1) ]

    error = assert_raises(Reminders::Error) { Reminders.add([]) }
    assert_match "Not authorized", error.message
    assert_match "Privacy & Security → Reminders", error.message
  end

  private
    def on_a_mac(replying:)
      MacScript.mac = -> { true }
      MacScript.osascript = -> { "/usr/bin/osascript" }
      MacScript.runner = ->(*command) { @calls << command; replying }
    end
end
