// The Mac's Calendar, through EventKit: every calendar added to it (iCloud,
// Google, Exchange) is read and written the same way. Run on the Mac:
//
//   osascript -l JavaScript lib/calendar/calendar.js '<json>'
//   osascript -l JavaScript lib/calendar/calendar.js https://host
//
// With JSON, one action:
//
//   { action: "busy", from, to, calendars }
//     Prints { busy: [{ start, end, all_day }] }: every event between from
//     and to (ISO 8601) on the named calendars (all of them when empty),
//     recurring events expanded, less those marked free.
//
//   { action: "sync", calendar, marker, from, to, events: [{ key, title, start, end, notes, url }] }
//     Makes the app's events between from and to match the list: an event
//     is the app's when its notes end with "<marker> <key>". Each listed
//     event is added or moved and retitled; any other of the app's events in
//     the window is removed. New events go on the named calendar, or the
//     default one when it is blank or not found. Prints { added, updated,
//     removed }.
//
// With the app's address, both, for an app that cannot reach the Mac itself
// (in a container): it fetches <host>/calendar.json, which holds a sync
// payload and a busy request, runs them, and posts what it read to
// <host>/calendar/busy. Prints what it did.
ObjC.import("Foundation")
ObjC.import("EventKit")

const ENTITY_EVENT = 0
const SPAN_THIS_EVENT = 0
const AVAILABILITY_FREE = 1
const AUTHORIZED = 3 // full access on macOS 14; authorized before it

function eventStore() {
  const store = $.EKEventStore.alloc.init
  if ($.EKEventStore.authorizationStatusForEntityType(ENTITY_EVENT) === AUTHORIZED) return store

  let done = false
  let granted = false
  const handler = function (ok, error) { granted = ok; done = true }
  if (store.respondsToSelector("requestFullAccessToEventsWithCompletion:")) store.requestFullAccessToEventsWithCompletion(handler)
  else store.requestAccessToEntityTypeCompletion(ENTITY_EVENT, handler)

  const until = $.NSDate.dateWithTimeIntervalSinceNow(60)
  while (!done && $.NSDate.date.compare(until) < 0) {
    $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.1))
  }
  if (!granted) throw new Error("Calendar access not granted")
  return store
}

function nsDate(iso) {
  return $.NSDate.dateWithTimeIntervalSince1970(new Date(iso).getTime() / 1000)
}

function iso(date) {
  return new Date(date.timeIntervalSince1970 * 1000).toISOString()
}

function each(array, fn) {
  const out = []
  for (let i = 0; i < array.count; i++) out.push(fn(array.objectAtIndex(i)))
  return out
}

function calendarsNamed(store, names) {
  const all = each(store.calendarsForEntityType(ENTITY_EVENT), (calendar) => calendar)
  if (!names || names.length === 0) return all
  return all.filter((calendar) => names.indexOf(calendar.title.js) !== -1)
}

function eventsBetween(store, from, to, calendars) {
  const list = calendars ? $.NSArray.arrayWithArray(calendars) : $()
  const predicate = store.predicateForEventsWithStartDateEndDateCalendars(nsDate(from), nsDate(to), calendars ? list : null)
  return each(store.eventsMatchingPredicate(predicate), (event) => event)
}

function busy(store, payload) {
  const calendars = payload.calendars && payload.calendars.length ? calendarsNamed(store, payload.calendars) : null
  if (calendars && calendars.length === 0) throw new Error("No calendar named " + payload.calendars.join(" or "))

  const events = eventsBetween(store, payload.from, payload.to, calendars)
  return {
    busy: events
      .filter((event) => event.availability !== AVAILABILITY_FREE)
      .map((event) => ({ start: iso(event.startDate), end: iso(event.endDate), all_day: event.allDay }))
  }
}

function notesKey(event, marker) {
  const notes = event.notes.isNil() ? "" : event.notes.js
  const match = notes.match(new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + " (\\S+)\\s*$"))
  return match ? match[1] : null
}

function save(store, event) {
  const error = $()
  if (!store.saveEventSpanCommitError(event, SPAN_THIS_EVENT, true, error)) throw new Error("Could not save " + event.title.js + ": " + error.localizedDescription.js)
}

function sync(store, payload) {
  const marker = payload.marker
  const existing = {}
  eventsBetween(store, payload.from, payload.to, null).forEach((event) => {
    const key = notesKey(event, marker)
    if (key) existing[key] = event
  })

  const named = payload.calendar ? calendarsNamed(store, [ payload.calendar ])[0] : null
  const calendar = named || store.defaultCalendarForNewEvents
  let added = 0
  let updated = 0

  ;(payload.events || []).forEach((item) => {
    let event = existing[item.key]
    if (event) {
      delete existing[item.key]
      updated++
    } else {
      event = $.EKEvent.eventWithEventStore(store)
      event.setCalendar(calendar)
      added++
    }
    event.setTitle(item.title)
    event.setStartDate(nsDate(item.start))
    event.setEndDate(nsDate(item.end))
    event.setNotes((item.notes ? item.notes + "\n\n" : "") + marker + " " + item.key)
    if (item.url) event.setURL($.NSURL.URLWithString(item.url))
    save(store, event)
  })

  let removed = 0
  Object.keys(existing).forEach((key) => {
    const error = $()
    if (!store.removeEventSpanCommitError(existing[key], SPAN_THIS_EVENT, true, error)) throw new Error("Could not remove an event: " + error.localizedDescription.js)
    removed++
  })

  return { added: added, updated: updated, removed: removed }
}

function request(url, body) {
  const req = $.NSMutableURLRequest.requestWithURL($.NSURL.URLWithString(url))
  req.setValueForHTTPHeaderField("application/json", "Accept")
  if (body) {
    req.setHTTPMethod("POST")
    req.setValueForHTTPHeaderField("application/json", "Content-Type")
    req.setHTTPBody($(JSON.stringify(body)).dataUsingEncoding($.NSUTF8StringEncoding))
  }
  const response = $()
  const error = $()
  const data = $.NSURLConnection.sendSynchronousRequestReturningResponseError(req, response, error)
  if (data.isNil()) throw new Error("Could not reach " + url + (error.isNil() ? "" : ": " + error.localizedDescription.js))
  const status = response.statusCode
  const text = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js
  if (status >= 400) throw new Error(url + " answered " + status + ": " + text.slice(0, 200))
  return text ? JSON.parse(text) : {}
}

function run(argv) {
  if (argv.length === 0) throw new Error("Give an action as JSON, or the app's address")

  const store = eventStore()
  if (/^https?:\/\//.test(argv[0])) {
    const base = argv[0].replace(/\/+$/, "")
    const plan = request(base + "/calendar.json")
    const synced = sync(store, plan.sync)
    const read = busy(store, plan.busy)
    const stored = request(base + "/calendar/busy", read)
    return JSON.stringify({ synced: synced, busy: read.busy.length, stored: stored })
  }

  const payload = JSON.parse(argv[0])
  if (payload.action === "busy") return JSON.stringify(busy(store, payload))
  if (payload.action === "sync") return JSON.stringify(sync(store, payload))
  throw new Error("Unknown action " + payload.action)
}
