// UI metadata and constants (labels, colours, sort orders). NOT data: the data
// (events, applicants, applications) comes from the backend via `api`. Kept on
// the frontend because it's pure presentation that the views/stores own.

// Status visuals for the event chip (label + colours).
export const STATUS_META = {
  draft: { label: 'Bozza', bg: '#F1F5F9', border: '#E2E8F0', fg: '#475569' },
  published: { label: 'Pubblicato', bg: '#F0FDF4', border: '#BBF7D0', fg: '#15803D' },
  cancelled: { label: 'Annullato', bg: '#FEF2F2', border: '#FECACA', fg: '#DC2626' },
}

// Cancellation reasons offered in the Staff cancel sheet.
export const REASONS = ['Maltempo', 'Sede non disponibile', 'Adesioni insufficienti', 'Altro']

// Capacity of the event whose candidature screen we manage (Tour della Prevenzione).
export const CAPACITY = 6

// Application lifecycle visuals (per-event status for the current volunteer).
// `none` has no meta (no chip).
export const VOLUNTEER_APP_META = {
  supporter: { label: 'Sostenitore', banner: 'Partecipi come sostenitore', bg: '#F0FDFA', border: '#99F6E4', fg: '#0F766E', icon: 'Heart' },
  pending: { label: 'In attesa di approvazione', banner: 'Adesione in attesa di approvazione', bg: '#FFFBEB', border: '#FDE68A', fg: '#B45309', icon: 'Hourglass' },
  approved: { label: 'Volontario approvato', banner: 'Sei approvato come volontario', bg: '#F0FDF4', border: '#BBF7D0', fg: '#15803D', icon: 'Check' },
  waitlist: { label: 'In lista di riserva', banner: 'Sei in lista di riserva', bg: '#EFF6FF', border: '#BFDBFE', fg: '#1D4ED8', icon: 'AlignJustify' },
  withdrawn: { label: 'Ritirato', banner: 'Hai ritirato la tua adesione', bg: '#F1F5F9', border: '#E2E8F0', fg: '#64748B', icon: 'LogOut' },
}

// Sort order for "Le mie adesioni" (ritirato in fondo).
export const VOLUNTEER_STATUS_ORDER = { approved: 0, pending: 1, waitlist: 2, supporter: 3, withdrawn: 4 }

// "Ingaggio" badge: visuals for the call-to-action shown to a volunteer when an
// event has not yet reached its minimum number of participants. Distinct from the
// status chip — it reflects the event's staffing need, not the volunteer's own
// application. The amber/attention tone matches "Posti limitati". `label(missing)`
// builds the count-aware text from the backend's `missingParticipants`.
export const VOLUNTEER_ENGAGEMENT_META = {
  bg: '#FFFBEB',
  border: '#FDE68A',
  fg: '#B45309',
  icon: 'UserPlus',
  label: (missing) =>
    missing === 1 ? 'Manca 1 volontario · candidati' : `Mancano ${missing} volontari · candidati`,
}
