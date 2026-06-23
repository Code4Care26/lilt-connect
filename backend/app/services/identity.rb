# Mock identity (Readme §10): there is no real login. The frontend sends a
# free-form name as X-Identity-Id on every request; the role is a pure function
# of that name, derived here so the backend is the single source of truth (the
# frontend never computes the role). Swap this for a real users table + auth
# when login lands — the controller API (current_identity_id / current_role)
# stays the same.
module Identity
  ROLES = %w[supporter volunteer staff].freeze

  # Suffix convention (prototype): "...staff" => staff, "...vol" => volunteer,
  # anything else (incl. blank/anonymous guest) => supporter. Case-insensitive,
  # surrounding whitespace ignored.
  def self.role_for(name)
    n = name.to_s.strip.downcase
    return "staff" if n.end_with?("staff")
    return "volunteer" if n.end_with?("vol")

    "supporter"
  end

  # Up to two initials from the name's words, uppercased (e.g. "Anna Staff" => "AS").
  def self.initials_for(name)
    name.to_s.strip.split(/\s+/).first(2).map { |w| w[0] }.join.upcase
  end

  # A stable avatar colour for a name (presentation only, for the staff roster).
  PALETTE = %w[#0D9488 #2563EB #7C3AED #DB2777 #CA8A04 #059669 #0891B2 #9333EA #475569].freeze
  def self.color_for(name)
    PALETTE[name.to_s.sum % PALETTE.size]
  end

  # Mock contact details for a name (prototype: no real users table). Both are
  # deterministic functions of the name so the same volunteer always gets the
  # same number/address. Replace with the real user record when auth lands.

  # An Italian mobile number, formatted for display ("+39 3XX XXXXXXX"). Callers
  # that need digits-only (e.g. wa.me) should strip non-digits.
  def self.phone_for(name)
    n = name.to_s.sum
    "+39 3#{format('%02d', n % 100)} #{format('%07d', (n * 7919) % 10_000_000)}"
  end

  # A plausible e-mail on a placeholder domain, derived from the name's words.
  def self.email_for(name)
    local = name.to_s.strip.downcase.gsub(/\s+/, ".").gsub(/[^a-z0-9.]/, "")
    local = "volontario" if local.blank?
    "#{local}@example.org"
  end
end
