# Canonical dataset, ported 1:1 from the frontend mock (frontend/src/data/seed.js).
# Lives under app/ so it's autoloaded: both db/seeds.rb and POST /api/reset call
# Seeds.run!. Must stay aligned with the frontend's expected shape.
#
# NOTE: field names are the English contract (applications_count / waitlist_count
# / description), NOT the frontend mock's original Italian keys — the frontend
# will be aligned to match.
module Seeds
  # Identity is mocked per request from the caller's name (see Identity / Readme
  # §10) — no seeded identities. Per-user state (applications, participations)
  # is NOT seeded either: a fresh identity starts empty. Only events and the
  # staff-side applicant roster are seeded as demo content.
  EVENTS = [
    {
      id: "e1",
      title: "Tour della Prevenzione",
      kind: "Tour della Prevenzione",
      subtitle: "Tappa 2 · screening gratuiti",
      date_label: "Sab 28 giu",
      time_label: "09:00 – 13:00",
      starts_at: Time.utc(2026, 6, 28, 9, 0),
      duration_minutes: 240,
      place: "Piazza dei Signori",
      address: "Piazza dei Signori, 35139 Padova",
      poster: "linear-gradient(135deg,#0F766E,#14B8A6)",
      icon: "Activity",
      badge: "Aperto a tutti",
      badge_bg: "#F0FDFA",
      badge_fg: "#0F766E",
      description: "Una giornata di sensibilizzazione e screening gratuiti negli stand LILT. I volontari accolgono il pubblico, distribuiscono materiale informativo e supportano il personale sanitario.",
      roles: ["Accoglienza pubblico", "Distribuzione materiale", "Allestimento stand"],
      slots: { "approved" => 8, "available" => 3 },
      applications_count: 9,
      waitlist_count: 3,
      status: "published",
      reason: nil
    },
    {
      id: "e2",
      title: "Cena di beneficenza",
      kind: "Raccolta fondi",
      subtitle: "A sostegno degli ambulatori",
      date_label: "Ven 11 lug",
      time_label: "dalle 20:00",
      starts_at: Time.utc(2026, 7, 11, 20, 0),
      duration_minutes: 180,
      place: "Sala La Fornace",
      address: "Via Rolando da Piazzola 26, Padova",
      poster: "linear-gradient(135deg,#115E59,#0D9488)",
      icon: "Heart",
      badge: "Aperto a tutti",
      badge_bg: "#F0FDFA",
      badge_fg: "#0F766E",
      description: "Una serata conviviale il cui ricavato sostiene gli ambulatori LILT. Cerchiamo volontari per accoglienza ospiti, servizio ai tavoli e gestione del banco solidale.",
      roles: ["Accoglienza ospiti", "Servizio ai tavoli", "Banco solidale"],
      slots: { "approved" => 5, "available" => 5 },
      applications_count: 0,
      waitlist_count: 0,
      status: "draft",
      reason: nil
    },
    {
      id: "e3",
      title: "Pigiama Run 2026",
      kind: "Evento solidale",
      subtitle: "Camminata serale in pigiama",
      date_label: "Dom 6 lug",
      time_label: "dalle 18:30",
      starts_at: Time.utc(2026, 7, 6, 18, 30),
      duration_minutes: 150,
      place: "Prato della Valle",
      address: "Prato della Valle, 35123 Padova",
      poster: "linear-gradient(135deg,#1E293B,#475569)",
      icon: "Moon",
      badge: "Posti limitati",
      badge_bg: "#FFFBEB",
      badge_fg: "#B45309",
      description: "La corsa-camminata non competitiva a sostegno dei piccoli pazienti oncologici. Servono volontari per i punti ristoro, l’accoglienza e il percorso.",
      roles: ["Punti ristoro", "Accoglienza", "Percorso"],
      slots: { "approved" => 18, "available" => 6 },
      applications_count: 24,
      waitlist_count: 5,
      status: "published",
      reason: nil
    },
    {
      id: "e4",
      title: "Festa del volontariato",
      kind: "Comunità",
      subtitle: "Conosci la rete LILT",
      date_label: "Sab 19 lug",
      time_label: "16:00 – 20:00",
      starts_at: Time.utc(2026, 7, 19, 16, 0),
      duration_minutes: 240,
      place: "Parco Iris",
      address: "Parco Iris, Arcella, Padova",
      poster: "linear-gradient(135deg,#0D9488,#2DD4BF)",
      icon: "Sparkles",
      badge: "Aperto a tutti",
      badge_bg: "#F0FDFA",
      badge_fg: "#0F766E",
      description: "Un pomeriggio per scoprire le attività di LILT e incontrare i volontari. Aiutaci all’accoglienza e agli stand informativi.",
      roles: ["Accoglienza", "Stand informativi"],
      slots: { "approved" => 4, "available" => 6 },
      applications_count: 0,
      waitlist_count: 0,
      status: "draft",
      reason: nil
    },
    {
      id: "e5",
      title: "Point in piazza",
      kind: "Sensibilizzazione",
      subtitle: "Banchetto informativo",
      date_label: "Mar 24 giu",
      time_label: "10:00 – 13:00",
      starts_at: Time.utc(2026, 6, 24, 10, 0),
      duration_minutes: 180,
      place: "Mercato di via Tiziano",
      address: "Via Tiziano Aspetti, Padova",
      poster: "linear-gradient(135deg,#334155,#64748B)",
      icon: "Send",
      badge: "Posti limitati",
      badge_bg: "#FFFBEB",
      badge_fg: "#B45309",
      description: "Banchetto di sensibilizzazione sulla prevenzione. I volontari distribuiscono materiale e parlano con i cittadini durante la mattina di mercato.",
      roles: ["Distribuzione materiale", "Informazione"],
      slots: { "approved" => 2, "available" => 2 },
      applications_count: 0,
      waitlist_count: 0,
      status: "cancelled",
      reason: "Adesioni insufficienti"
    }
  ].freeze

  # Wipe and recreate the demo content. Only events are seeded; per-user state
  # (EventApplication / Participation) is left empty — it is created through real
  # use (volunteers apply, supporters join, staff manage). Children before
  # parents would matter for FKs, but events have no seeded children now.
  def self.run!
    ApplicationRecord.transaction do
      EventApplication.delete_all
      Participation.delete_all
      Event.delete_all

      Event.insert_all(EVENTS.map { |e| timestamped(e) })
    end
  end

  # insert_all skips Active Record timestamp magic, so set them explicitly.
  def self.timestamped(attrs)
    now = Time.current
    attrs.merge(created_at: now, updated_at: now)
  end
end
