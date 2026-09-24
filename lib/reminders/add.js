// Adds items to a list in Apple Reminders: the shopping list, or what to thaw.
// Run on the Mac:
//
//   osascript -l JavaScript lib/reminders/add.js '<json>'
//   osascript -l JavaScript lib/reminders/add.js https://host/shopping.json
//
// The JSON is { list, items: [{ title, notes, due }] }, due an optional ISO
// 8601 time the reminder falls due. The list is created if it does not exist. An item whose title matches a reminder already on the list
// and not completed is skipped, so running it again adds only what is new.
// Prints { list, added, skipped } as JSON.
ObjC.import("Foundation")

function read(source) {
  if (!/^https?:\/\//.test(source)) return source

  const data = $.NSData.dataWithContentsOfURL($.NSURL.URLWithString(source))
  if (data.isNil()) throw new Error("Could not fetch " + source)
  return $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js
}

function run(argv) {
  if (argv.length === 0) throw new Error("Give the items as JSON, or their URL")

  const payload = JSON.parse(read(argv[0]))
  const listName = payload.list || "Groceries"
  const reminders = Application("Reminders")

  let list = reminders.lists.whose({ name: listName })[0]
  if (!list.exists()) list = reminders.make({ new: "list", withProperties: { name: listName } })

  const open = new Set(list.reminders.whose({ completed: false }).name())
  let added = 0
  let skipped = 0

  for (const item of payload.items || []) {
    if (open.has(item.title)) {
      skipped++
      continue
    }
    const properties = { name: item.title, body: item.notes || "" }
    if (item.due) properties.dueDate = new Date(item.due)
    reminders.make({ new: "reminder", at: list, withProperties: properties })
    open.add(item.title)
    added++
  }

  return JSON.stringify({ list: listName, added: added, skipped: skipped })
}
