// Client-side "export" helpers for an event detail: copy its address to the
// clipboard, and download an .ics so the user can drop the event into their
// calendar. Both work entirely in the browser — no backend round-trip.

// Copy text to the clipboard. The async Clipboard API is the modern path; we
// keep a hidden-textarea fallback for insecure contexts (http / older Safari)
// where navigator.clipboard is undefined. Returns true on success.
export async function copyToClipboard(text) {
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text)
      return true
    }
  } catch {
    // fall through to the legacy path
  }
  try {
    const ta = document.createElement('textarea')
    ta.value = text
    ta.setAttribute('readonly', '')
    ta.style.position = 'fixed'
    ta.style.opacity = '0'
    document.body.appendChild(ta)
    ta.select()
    const ok = document.execCommand('copy')
    document.body.removeChild(ta)
    return ok
  } catch {
    return false
  }
}

// "Piazza dei Signori — Piazza dei Signori, 35139 Padova": the place name plus
// its street address, deduped if the two happen to be identical.
export function eventAddressText(ev) {
  const parts = [ev.place, ev.address].filter(Boolean)
  return [...new Set(parts)].join(' — ')
}

// A human-readable, paste-anywhere summary of the event: everything someone
// would want when forwarding it to a friend. Blank fields are dropped so the
// text never shows dangling separators or empty lines.
export function eventShareText(ev) {
  const when = [ev.dateLabel, ev.timeLabel].filter(Boolean).join(' · ')
  const where = eventAddressText(ev)
  const lines = [
    ev.title ? `LILT · ${ev.title}` : 'Evento LILT',
    ev.subtitle || null,
    '',
    when ? `📅 ${when}` : null,
    where ? `📍 ${where}` : null,
    ev.description ? `\n${ev.description}` : null,
  ].filter((line) => line !== null)
  return lines.join('\n').trim()
}

// Share the event via the native share sheet when available (mobile), falling
// back to copying the summary on desktop / unsupported browsers. Returns one
// of: 'shared' | 'copied' | 'cancelled' | 'failed' so the caller can pick the
// right feedback (and stay silent when the user dismisses the share sheet).
export async function shareEvent(ev) {
  const text = eventShareText(ev)
  const title = ev.title || 'Evento LILT'
  if (navigator.share) {
    try {
      await navigator.share({ title, text })
      return 'shared'
    } catch (err) {
      if (err?.name === 'AbortError') return 'cancelled'
      // a genuine failure (not a user cancel) → fall through to copy
    }
  }
  const ok = await copyToClipboard(text)
  return ok ? 'copied' : 'failed'
}

// iCal TEXT values escape backslash, comma, semicolon and newlines (RFC 5545).
function escapeIcs(value) {
  return String(value ?? '')
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\r?\n/g, '\\n')
}

// "2026-06-28T09:00:00Z" -> "20260628T090000Z" (iCal UTC basic format).
function toIcsUtc(date) {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')
}

// Long content lines must be folded at 75 octets with a leading space on the
// continuation (RFC 5545 §3.1). Folding by character is good enough for the
// short ASCII-ish strings we emit here.
function foldLine(line) {
  if (line.length <= 75) return line
  const chunks = []
  let rest = line
  chunks.push(rest.slice(0, 75))
  rest = rest.slice(75)
  while (rest.length > 74) {
    chunks.push(' ' + rest.slice(0, 74))
    rest = rest.slice(74)
  }
  if (rest) chunks.push(' ' + rest)
  return chunks.join('\r\n')
}

// Build a single-VEVENT calendar for the event. Needs ev.startsAt (ISO8601);
// returns null when it's missing, since without a start there is no event.
export function buildIcs(ev) {
  if (!ev?.startsAt) return null
  const start = new Date(ev.startsAt)
  if (Number.isNaN(start.getTime())) return null
  const end = new Date(start.getTime() + (ev.durationMinutes || 60) * 60_000)

  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//LILT//Eventi//IT',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    `UID:${escapeIcs(ev.id)}@lilt-eventi`,
    `DTSTAMP:${toIcsUtc(new Date())}`,
    `DTSTART:${toIcsUtc(start)}`,
    `DTEND:${toIcsUtc(end)}`,
    `SUMMARY:${escapeIcs(ev.title)}`,
    ev.description ? `DESCRIPTION:${escapeIcs(ev.description)}` : null,
    `LOCATION:${escapeIcs(eventAddressText(ev))}`,
    'END:VEVENT',
    'END:VCALENDAR',
  ].filter(Boolean)

  return lines.map(foldLine).join('\r\n')
}

// Italian labels for the applicant lifecycle, used in the participants export.
const STATUS_LABELS = {
  pending: 'In attesa',
  approved: 'Approvato',
  waitlist: 'In riserva',
  withdrawn: 'Ritirato',
  supporter: 'Sostenitore',
}

// Quote a CSV field per RFC 4180: wrap in double quotes and double any inner
// quote. We always quote so commas/semicolons/newlines in names never break a row.
function csvField(value) {
  return `"${String(value ?? '').replace(/"/g, '""')}"`
}

// Build a CSV of an event's participants: name, status, phone, email. Returns
// null when there are no participants (nothing to export).
export function participantsCsv(applicants) {
  if (!applicants?.length) return null
  const header = ['Nome', 'Stato', 'Telefono', 'Email']
  const rows = applicants.map((a) => [
    a.name,
    STATUS_LABELS[a.status] || a.status,
    a.phone || '',
    a.email || '',
  ])
  // Prepend a UTF-8 BOM so Excel opens accented names correctly.
  return '\uFEFF' + [header, ...rows].map((r) => r.map(csvField).join(',')).join('\r\n')
}

// Generate the participants CSV and trigger a download. Returns false when the
// event has no participants. Caller can surface a toast accordingly.
export function downloadParticipantsCsv(event, applicants) {
  const csv = participantsCsv(applicants)
  if (!csv) return false
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `partecipanti-${slugify(event?.title)}.csv`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
  return true
}

function slugify(text) {
  return String(text || 'evento')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40) || 'evento'
}

// Generate the .ics and trigger a download. Returns false when the event lacks
// a start date (nothing to export). Caller can surface a toast accordingly.
export function downloadEventIcs(ev) {
  const ics = buildIcs(ev)
  if (!ics) return false
  const blob = new Blob([ics], { type: 'text/calendar;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${slugify(ev.title)}.ics`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
  return true
}
