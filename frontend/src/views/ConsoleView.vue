<script setup>
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import LucideIcon from '../components/ui/LucideIcon.vue'
import Avatar from '../components/ui/Avatar.vue'
import ProgressBar from '../components/ui/ProgressBar.vue'
import { useUiStore } from '../stores/ui'
import { useStaffStore } from '../stores/staff'

// Console Staff — una schermata di triage che risponde a due domande quotidiane
// dello staff: "cosa rischia di saltare?" (gestione) e "chi sto perdendo?"
// (mantenimento). I dati vengono da GET /api/staff/dashboard (ibrido: eventi
// reali + parti per-volontario generate stabilmente, come "Il tuo impatto").
// Le azioni sono ancora dimostrative (toast) finché non le colleghiamo.
const router = useRouter()
const ui = useUiStore()
const store = useStaffStore()

const d = computed(() => store.dashboard)
const health = computed(() => store.dashboard?.volunteerHealth)

// A. Eventi a rischio, ordinati per urgenza reale = mancanti / giorni a starts_at.
const atRisk = computed(() =>
  [...(store.dashboard?.atRiskEvents || [])].sort(
    (a, b) => b.missing / b.daysToStart - a.missing / a.daysToStart,
  ),
)

const demo = (msg) => ui.showToast(msg)
const goManage = (eventId) => router.push(`/events/${eventId}/applications`)

onMounted(() => store.loadDashboard())
</script>

<template>
  <div class="flex h-full flex-col">
    <!-- Brand header (coerente con EventsView) -->
    <header class="flex flex-none items-center justify-between border-b border-line bg-white px-[18px] pb-3.5 pt-1.5">
      <div class="flex flex-col gap-px">
        <span class="text-[26px] font-extrabold leading-none tracking-wide text-lilt">LILT</span>
        <span class="text-xs font-medium leading-tight tracking-wide text-muted">gocciolina</span>
      </div>
      <span class="inline-flex h-[26px] items-center gap-1.5 rounded-full border border-[#C7D2FE] bg-[#EEF2FF] px-2.5">
        <LucideIcon name="ShieldCheck" :size="13" :stroke-width="2.2" color="#4338CA" />
        <span class="text-[11px] font-bold leading-none text-[#4338CA]">Staff</span>
      </span>
    </header>

    <div class="scrl flex-1 overflow-y-auto px-4 pb-[calc(96px+env(safe-area-inset-bottom))] pt-4">
      <div class="mb-3 px-0.5 text-[19px] font-bold tracking-tight text-ink">Console</div>

      <!-- Caricamento (i dati arrivano da GET /api/staff/dashboard) -->
      <p v-if="!d" class="py-16 text-center text-sm text-faint">Carico la console…</p>

      <template v-else>
      <!-- ── Fascia KPI ───────────────────────────────────────────────────── -->
      <div class="mb-5 grid grid-cols-3 gap-2.5">
        <div class="rounded-2xl border border-[#FDE68A] bg-[#FFFBEB] p-3">
          <div class="text-[26px] font-extrabold leading-none text-[#B45309]">{{ d.kpis.atRiskEvents }}</div>
          <div class="mt-1.5 text-[11px] font-semibold leading-tight text-[#92400E]">eventi a rischio</div>
        </div>
        <div class="rounded-2xl border border-line bg-white p-3">
          <div class="text-[26px] font-extrabold leading-none text-ink">{{ d.kpis.pendingApplications }}</div>
          <div class="mt-1.5 text-[11px] font-semibold leading-tight text-muted">in attesa · max {{ d.kpis.oldestPendingDays }}gg</div>
        </div>
        <div class="rounded-2xl border border-[#FECACA] bg-[#FEF2F2] p-3">
          <div class="text-[26px] font-extrabold leading-none text-[#DC2626]">{{ d.kpis.atRiskVolunteers }}</div>
          <div class="mt-1.5 text-[11px] font-semibold leading-tight text-[#991B1B]">volontari a rischio</div>
        </div>
      </div>

      <!-- ── A. Eventi a rischio ──────────────────────────────────────────── -->
      <section class="mb-6">
        <div class="mb-2.5 flex items-center gap-2">
          <LucideIcon name="TriangleAlert" :size="17" :stroke-width="2.2" color="#B45309" />
          <h2 class="text-[15px] font-bold text-ink">Eventi a rischio</h2>
        </div>
        <p class="mb-3 text-[12px] leading-snug text-muted">Pubblicati sotto il minimo. In cima i più urgenti (mancano più volontari, manca meno tempo).</p>

        <div class="flex flex-col gap-2.5">
          <div v-for="ev in atRisk" :key="ev.id" class="rounded-2xl border border-line bg-white p-3.5">
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <div class="truncate text-[14px] font-bold text-ink">{{ ev.title }}</div>
                <div class="mt-0.5 text-[11.5px] text-faint">{{ ev.kind }} · {{ ev.dateLabel }}</div>
              </div>
              <span class="inline-flex flex-none items-center gap-1 rounded-full bg-[#FFFBEB] px-2.5 py-1">
                <LucideIcon name="Clock" :size="12" :stroke-width="2.3" color="#B45309" />
                <span class="text-[11px] font-bold leading-none text-[#B45309]">tra {{ ev.daysToStart }} gg</span>
              </span>
            </div>

            <div class="mt-3 flex items-center justify-between text-[11.5px] font-semibold">
              <span class="text-[#B45309]">Mancano {{ ev.missing }} volontari</span>
              <span class="text-muted">{{ ev.confirmed }}/{{ ev.min }} confermati</span>
            </div>
            <div class="mt-1.5">
              <ProgressBar :pct="Math.round((ev.confirmed / ev.min) * 100)" color="#F59E0B" />
            </div>

            <div class="mt-3 flex gap-2">
              <button
                class="inline-flex h-9 flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-full bg-brand text-[12.5px] font-semibold text-white transition-colors hover:bg-brand-dark"
                @click="goManage(ev.id)"
              >
                <LucideIcon name="Users" :size="15" :stroke-width="2.2" color="#fff" />
                Apri candidature
              </button>
              <button
                v-if="ev.waitlistAvailable > 0"
                class="inline-flex h-9 cursor-pointer items-center justify-center gap-1.5 rounded-full border border-line bg-white px-3 text-[12.5px] font-semibold text-[#1D4ED8] transition-colors hover:bg-canvas"
                @click="demo(`Promuovi ${ev.waitlistAvailable} dalla riserva — demo`)"
              >
                <LucideIcon name="UserPlus" :size="15" :stroke-width="2.2" color="#1D4ED8" />
                Riserva {{ ev.waitlistAvailable }}
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- ── B. In attesa di risposta ─────────────────────────────────────── -->
      <section class="mb-6">
        <div class="mb-2.5 flex items-center gap-2">
          <LucideIcon name="Hourglass" :size="16" :stroke-width="2.2" color="#475569" />
          <h2 class="text-[15px] font-bold text-ink">In attesa di una tua risposta</h2>
        </div>
        <p class="mb-3 text-[12px] leading-snug text-muted">Più aspettano, più rischi di perderli. Le più vecchie in cima.</p>

        <div class="overflow-hidden rounded-2xl border border-line bg-white">
          <div
            v-for="(a, i) in d.pendingApplications"
            :key="a.id"
            class="flex items-center gap-3 px-3.5 py-2.5"
            :class="i > 0 ? 'border-t border-line' : ''"
          >
            <Avatar :initials="a.initials" :color="a.color" :size="36" />
            <div class="min-w-0 flex-1">
              <div class="truncate text-[13.5px] font-semibold text-ink">{{ a.name }}</div>
              <div class="truncate text-[11.5px] text-faint">{{ a.eventTitle }}</div>
            </div>
            <span
              class="flex-none text-[11px] font-bold"
              :class="a.waitingDays >= 5 ? 'text-[#DC2626]' : 'text-muted'"
            >
              {{ a.waitingDays === 1 ? '1 giorno' : `${a.waitingDays} giorni` }}
            </span>
          </div>
        </div>
      </section>

      <!-- ── C. Salute dei volontari ──────────────────────────────────────── -->
      <section class="mb-6">
        <div class="mb-2.5 flex items-center gap-2">
          <LucideIcon name="HeartHandshake" :size="17" :stroke-width="2.2" color="#0D9488" />
          <h2 class="text-[15px] font-bold text-ink">Salute dei volontari</h2>
        </div>

        <!-- Dormienti -->
        <div class="mb-2.5 rounded-2xl border border-line bg-white p-3.5">
          <div class="mb-2 flex items-center gap-1.5">
            <LucideIcon name="Moon" :size="14" :stroke-width="2.2" color="#64748B" />
            <span class="text-[12.5px] font-bold text-ink">Dormienti</span>
            <span class="text-[11px] text-faint">· inattivi da settimane</span>
          </div>
          <div v-for="(v, i) in health.dormant" :key="v.name" class="flex items-center gap-3" :class="i > 0 ? 'mt-2.5' : ''">
            <Avatar :initials="v.initials" :color="v.color" :size="34" />
            <div class="min-w-0 flex-1">
              <div class="truncate text-[13px] font-semibold text-ink">{{ v.name }}</div>
              <div class="text-[11px] text-faint">{{ v.pastEvents }} eventi · visto {{ v.lastActivityWeeks }} settimane fa</div>
            </div>
            <button
              class="flex-none cursor-pointer rounded-full border border-line bg-white px-3 py-1.5 text-[11.5px] font-semibold text-brand transition-colors hover:bg-canvas"
              @click="demo(`Ricontatta ${v.name} — demo`)"
            >
              Ricontatta
            </button>
          </div>
        </div>

        <!-- Ritiri recenti -->
        <div class="mb-2.5 rounded-2xl border border-[#FECACA] bg-[#FEF2F2] p-3.5">
          <div class="mb-2 flex items-center gap-1.5">
            <LucideIcon name="LogOut" :size="14" :stroke-width="2.2" color="#DC2626" />
            <span class="text-[12.5px] font-bold text-[#991B1B]">Ritiri recenti</span>
          </div>
          <div v-for="(v, i) in health.recentWithdrawals" :key="v.name" class="flex items-center gap-3" :class="i > 0 ? 'mt-2.5' : ''">
            <Avatar :initials="v.initials" :color="v.color" :size="34" />
            <div class="min-w-0 flex-1">
              <div class="truncate text-[13px] font-semibold text-ink">{{ v.name }}</div>
              <div class="truncate text-[11px] text-[#B91C1C]">ha lasciato "{{ v.eventTitle }}" · {{ v.daysAgo }} gg fa</div>
            </div>
          </div>
        </div>

        <!-- Riserva ferma -->
        <div class="mb-2.5 rounded-2xl border border-[#BFDBFE] bg-[#EFF6FF] p-3.5">
          <div class="mb-2 flex items-center gap-1.5">
            <LucideIcon name="AlignJustify" :size="14" :stroke-width="2.2" color="#1D4ED8" />
            <span class="text-[12.5px] font-bold text-[#1E3A8A]">In riserva, mai promossi</span>
          </div>
          <div v-for="(v, i) in health.stuckWaitlist" :key="v.name" class="flex items-center gap-3" :class="i > 0 ? 'mt-2.5' : ''">
            <Avatar :initials="v.initials" :color="v.color" :size="34" />
            <div class="min-w-0 flex-1">
              <div class="truncate text-[13px] font-semibold text-ink">{{ v.name }}</div>
              <div class="truncate text-[11px] text-[#1D4ED8]">{{ v.eventTitle }} · da {{ v.weeks }} settimane</div>
            </div>
          </div>
        </div>

        <!-- Affidabilità -->
        <div class="rounded-2xl border border-line bg-white p-3.5">
          <div class="mb-2.5 flex items-center gap-1.5">
            <LucideIcon name="BadgeCheck" :size="14" :stroke-width="2.2" color="#15803D" />
            <span class="text-[12.5px] font-bold text-ink">Affidabilità</span>
            <span class="text-[11px] text-faint">· presenze su adesioni</span>
          </div>
          <div v-for="(v, i) in health.reliability" :key="v.name" class="flex items-center gap-3" :class="i > 0 ? 'mt-2.5' : ''">
            <Avatar :initials="v.initials" :color="v.color" :size="34" />
            <div class="min-w-0 flex-1">
              <div class="flex items-center justify-between">
                <span class="truncate text-[13px] font-semibold text-ink">{{ v.name }}</span>
                <span
                  class="ml-2 flex-none text-[12px] font-bold"
                  :class="v.pct >= 80 ? 'text-[#15803D]' : v.pct >= 65 ? 'text-[#B45309]' : 'text-[#DC2626]'"
                >
                  {{ v.pct }}%
                </span>
              </div>
              <div class="mt-1">
                <ProgressBar :pct="v.pct" :color="v.pct >= 80 ? '#22C55E' : v.pct >= 65 ? '#F59E0B' : '#EF4444'" />
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- ── D. Riserva da valorizzare ────────────────────────────────────── -->
      <section>
        <div class="mb-2.5 flex items-center gap-2">
          <LucideIcon name="UserPlus" :size="17" :stroke-width="2.2" color="#1D4ED8" />
          <h2 class="text-[15px] font-bold text-ink">Riserva da valorizzare</h2>
        </div>
        <p class="mb-3 text-[12px] leading-snug text-muted">Volontari in riserva su eventi che hanno ancora bisogno: promuovili e chiudi il buco.</p>

        <div class="flex flex-col gap-2.5">
          <div v-for="m in d.waitlistMatches" :key="m.id" class="flex items-center gap-3 rounded-2xl border border-line bg-white p-3">
            <Avatar :initials="m.initials" :color="m.color" :size="38" />
            <div class="min-w-0 flex-1">
              <div class="truncate text-[13.5px] font-semibold text-ink">{{ m.name }}</div>
              <div class="truncate text-[11.5px] text-faint">{{ m.eventTitle }} · mancano {{ m.eventNeeds }}</div>
            </div>
            <button
              class="inline-flex h-9 flex-none cursor-pointer items-center gap-1.5 rounded-full bg-[#1D4ED8] px-3.5 text-[12.5px] font-semibold text-white transition-colors hover:bg-[#1E40AF]"
              @click="demo(`Promuovi ${m.name} su ${m.eventTitle} — demo`)"
            >
              Promuovi
              <LucideIcon name="ArrowRight" :size="15" :stroke-width="2.4" color="#fff" />
            </button>
          </div>
        </div>
      </section>
      </template>
    </div>
  </div>
</template>
