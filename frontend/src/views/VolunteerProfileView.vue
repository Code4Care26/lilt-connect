<script setup>
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
import { useVolunteerStore } from '../stores/volunteer'
import { usePushStore } from '../stores/push'
import { useUiStore } from '../stores/ui'
import { VOLUNTEER_APP_META } from '../data/meta'
import Avatar from '../components/ui/Avatar.vue'
import LucideIcon from '../components/ui/LucideIcon.vue'

// Volunteer profile: reached by tapping the avatar in the header (not a tab),
// so it has a back button. Identity, a shortcut to the states legend, and the
// demo data reset (decision G).
const router = useRouter()
const session = useSessionStore()
const store = useVolunteerStore()
const push = usePushStore()
const ui = useUiStore()

// "Il tuo impatto": fetched from GET /api/volunteer/stats (placeholder random
// data backend-side for now). Null until loaded → the section stays hidden.
const stats = computed(() => store.stats)
const countChips = computed(() =>
  stats.value
    ? ['approved', 'pending', 'waitlist', 'supporter'].map((key) => ({
        key,
        count: stats.value.counts[key],
        meta: VOLUNTEER_APP_META[key],
      }))
    : [],
)

onMounted(() => {
  store.loadStats()
  // Reflect the current push state without prompting (permission is only ever
  // requested from the explicit toggle below — never on load).
  push.refresh()
})

// Toggle the background push subscription. enablePush() requests the OS
// permission, so it MUST run from this user gesture. Feedback via the shared toast.
async function toggleNotifications() {
  if (push.busy) return
  if (push.subscribed) {
    await push.disablePush()
    ui.showToast('Notifiche disattivate', 'info')
    return
  }
  const ok = await push.enablePush()
  if (ok) ui.showToast('Notifiche attivate', 'ok')
  else if (push.denied) ui.showToast('Notifiche bloccate nelle impostazioni del browser', 'danger')
  else ui.showToast('Impossibile attivare le notifiche', 'danger')
}

async function switchUser() {
  await session.logout()
  router.push('/supporter/login')
}
</script>

<template>
  <div class="flex h-full flex-col">
    <header class="flex flex-none items-center gap-3 border-b border-line bg-white px-[18px] pb-3.5 pt-3.5">
      <button
        class="flex h-[38px] w-[38px] flex-none cursor-pointer items-center justify-center rounded-full bg-[#F1F5F9]"
        @click="router.push('/volunteer/events')"
      >
        <LucideIcon name="ChevronLeft" :size="20" :stroke-width="2.2" color="#0F172A" />
      </button>
      <div class="text-[19px] font-bold tracking-tight text-ink">Profilo</div>
    </header>

    <div class="scrl flex-1 overflow-y-auto px-[18px] pb-[calc(96px+env(safe-area-inset-bottom))] pt-6">
      <div class="flex flex-col items-center text-center">
        <Avatar :initials="session.currentUser.initials" :color="session.currentUser.color" :size="72" />
        <div class="mt-3 text-lg font-bold tracking-tight text-ink">{{ session.currentUser.name }}</div>
        <div class="mt-0.5 text-sm font-medium text-muted">Volontaria · LILT Padova</div>
        <span class="mt-3 inline-flex h-[26px] items-center gap-1.5 rounded-full border border-[#99F6E4] bg-brand-tint px-2.5">
          <LucideIcon name="ShieldCheck" :size="13" :stroke-width="2.2" color="#0F766E" />
          <span class="text-[11px] font-bold leading-none text-brand-dark">{{ session.roleLabel }}</span>
        </span>
        <div v-if="stats" class="mt-2 flex items-center gap-1.5 text-xs font-medium text-muted">
          <LucideIcon name="CalendarHeart" :size="13" :stroke-width="2.2" color="#94A3B8" />
          Con noi da {{ stats.since }}
        </div>
      </div>

      <!-- Hero: Il tuo impatto -->
      <div v-if="stats" class="mt-8 overflow-hidden rounded-2xl border border-[#99F6E4] bg-brand-tint">
        <div class="flex items-center gap-2 px-5 pt-5">
          <LucideIcon name="Sparkles" :size="16" :stroke-width="2.2" color="#0F766E" />
          <div class="text-[11px] font-bold uppercase tracking-wide text-brand-dark">Il tuo impatto</div>
        </div>
        <div class="grid grid-cols-2 gap-3 p-5 pt-3">
          <div class="rounded-xl bg-white p-3.5">
            <div class="flex items-center gap-1.5">
              <LucideIcon name="CalendarCheck" :size="22" :stroke-width="2.2" color="#0F766E" />
              <span class="text-[30px] font-extrabold leading-none tracking-tight text-brand-dark">{{ stats.impact }}</span>
            </div>
            <div class="mt-1 text-[11.5px] font-semibold text-brand-dark/80">eventi a cui hai dato una mano</div>
          </div>
          <div class="rounded-xl bg-white p-3.5">
            <div class="flex items-center gap-1.5">
              <LucideIcon name="Clock" :size="22" :stroke-width="2.2" color="#0F766E" />
              <span class="flex items-baseline gap-1">
                <span class="text-[30px] font-extrabold leading-none tracking-tight text-brand-dark">{{ stats.hours }}</span>
                <span class="text-[15px] font-bold text-brand-dark/80">h</span>
              </span>
            </div>
            <div class="mt-1 text-[11.5px] font-semibold text-brand-dark/80">ore di volontariato donate</div>
          </div>
        </div>
        <div
          v-if="stats.decisive > 0"
          class="flex items-center gap-2 border-t border-[#99F6E4]/70 bg-white/50 px-5 py-3"
        >
          <LucideIcon name="Flame" :size="16" :stroke-width="2.2" color="#B45309" />
          <span class="text-[12.5px] font-semibold text-[#B45309]">
            Decisiva per {{ stats.decisive }} eventi che rischiavano di saltare
          </span>
        </div>
      </div>

      <!-- Counters per stato adesione -->
      <div v-if="stats" class="mt-3 grid grid-cols-4 gap-2">
        <div
          v-for="chip in countChips"
          :key="chip.key"
          class="flex flex-col items-center gap-1 rounded-xl border py-2.5"
          :style="{ backgroundColor: chip.meta.bg, borderColor: chip.meta.border }"
        >
          <LucideIcon :name="chip.meta.icon" :size="15" :stroke-width="2.2" :color="chip.meta.fg" />
          <span class="text-[17px] font-extrabold leading-none" :style="{ color: chip.meta.fg }">{{ chip.count }}</span>
        </div>
      </div>
      <div v-if="stats" class="mt-1.5 flex flex-wrap justify-center gap-x-3 gap-y-0.5 px-1 text-[10.5px] font-medium text-muted">
        <span v-for="chip in countChips" :key="chip.key">{{ chip.count }} {{ chip.meta.label.toLowerCase() }}</span>
      </div>

      <!-- I tuoi ambiti -->
      <div v-if="stats && stats.areas.length" class="mt-4 rounded-2xl border border-line bg-white p-4">
        <div class="flex items-center gap-2">
          <LucideIcon name="Tag" :size="15" :stroke-width="2.2" color="#0F766E" />
          <div class="text-[13px] font-semibold text-ink">I tuoi ambiti</div>
        </div>
        <div class="mt-2.5 flex flex-wrap gap-1.5">
          <span
            v-for="area in stats.areas"
            :key="area"
            class="inline-flex h-[26px] items-center rounded-full border border-line bg-canvas px-2.5 text-[11.5px] font-semibold text-[#334155]"
          >
            {{ area }}
          </span>
        </div>
      </div>

      <!-- Ruoli ricoperti -->
      <div v-if="stats && stats.roles.length" class="mt-3 rounded-2xl border border-line bg-white p-4">
        <div class="flex items-center gap-2">
          <LucideIcon name="HandHeart" :size="15" :stroke-width="2.2" color="#0F766E" />
          <div class="text-[13px] font-semibold text-ink">Ruoli ricoperti</div>
        </div>
        <div class="mt-2.5 space-y-1.5">
          <div v-for="role in stats.roles" :key="role.label" class="flex items-center justify-between">
            <span class="text-[12.5px] font-medium text-[#334155]">{{ role.label }}</span>
            <span class="text-[12px] font-bold text-muted">×{{ role.count }}</span>
          </div>
        </div>
        <div
          v-if="stats.reliability >= 80"
          class="mt-3 flex items-center gap-2 border-t border-line pt-3"
        >
          <LucideIcon name="BadgeCheck" :size="15" :stroke-width="2.2" color="#15803D" />
          <span class="text-[12px] font-semibold text-[#15803D]">
            Presenza confermata sul {{ stats.reliability }}% delle tue adesioni
          </span>
        </div>
      </div>

      <button
        class="mt-4 flex w-full items-center gap-3 rounded-2xl border border-line bg-white p-4 text-left transition-colors hover:bg-canvas"
        @click="router.push('/volunteer/states')"
      >
        <div class="flex h-10 w-10 flex-none items-center justify-center rounded-xl bg-brand-tint">
          <LucideIcon name="Info" :size="18" color="#0F766E" />
        </div>
        <div class="flex-1">
          <div class="text-[13px] font-semibold text-ink">Stati dell'adesione</div>
          <div class="text-xs text-muted">Come funziona il ciclo di un'adesione</div>
        </div>
        <LucideIcon name="ArrowRight" :size="18" color="#94A3B8" />
      </button>

      <!-- Notifiche push (Web Push) — solo dove l'API è disponibile. Su iOS
           compare unicamente quando la PWA è installata e gira standalone. -->
      <div v-if="push.supported" class="mt-4 rounded-2xl border border-line bg-white p-4">
        <div class="flex items-center gap-3">
          <div class="flex h-10 w-10 flex-none items-center justify-center rounded-xl bg-brand-tint">
            <LucideIcon name="Bell" :size="18" color="#0F766E" />
          </div>
          <div class="flex-1">
            <div class="text-[13px] font-semibold text-ink">Notifiche push</div>
            <div class="text-xs leading-relaxed text-muted">
              Avvisami quando la mia candidatura viene accettata, anche ad app chiusa.
            </div>
          </div>
        </div>
        <button
          class="mt-3 flex h-11 w-full cursor-pointer items-center justify-center gap-2 rounded-xl border text-[13px] font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-60"
          :class="
            push.subscribed
              ? 'border-line bg-white text-[#334155] hover:bg-canvas'
              : 'border-brand-dark bg-brand text-white hover:bg-brand-dark'
          "
          :disabled="push.busy || push.denied"
          @click="toggleNotifications"
        >
          <LucideIcon
            :name="push.subscribed ? 'BellOff' : 'Bell'"
            :size="16"
            :stroke-width="2.2"
            :color="push.subscribed ? '#334155' : '#fff'"
          />
          {{ push.denied ? 'Notifiche bloccate dal browser' : push.subscribed ? 'Disattiva notifiche' : 'Attiva notifiche' }}
        </button>
      </div>

      <div class="mt-4 rounded-2xl border border-line bg-white p-4">
        <div class="text-[13px] font-semibold text-ink">Dati demo</div>
        <p class="mt-1 text-xs leading-relaxed text-muted">
          Risincronizza se la schermata sembra disallineata: ricarica i dati dal server, senza perdere nulla. «Ripristina dati demo» riporta invece tutto allo stato iniziale.
        </p>
        <button
          class="mt-3 flex h-11 w-full items-center justify-center gap-2 rounded-xl border border-[#99F6E4] bg-[#F0FDFA] text-[13px] font-semibold text-[#0F766E] transition-colors hover:bg-[#CCFBF1]"
          @click="store.resync()"
        >
          <LucideIcon name="RefreshCw" :size="16" :stroke-width="2.2" />
          Risincronizza
        </button>
        <button
          class="mt-2 flex h-11 w-full items-center justify-center gap-2 rounded-xl border border-line bg-white text-[13px] font-semibold text-[#334155] transition-colors hover:bg-canvas"
          @click="store.resetData()"
        >
          <LucideIcon name="RotateCcw" :size="16" :stroke-width="2.2" />
          Ripristina dati demo
        </button>
      </div>

      <button
        class="mt-4 flex h-11 w-full cursor-pointer items-center justify-center gap-2 rounded-xl border border-line bg-white text-[13px] font-semibold text-[#334155] transition-colors hover:bg-canvas"
        @click="switchUser"
      >
        <LucideIcon name="LogOut" :size="16" :stroke-width="2.2" />
        Cambia utente
      </button>
    </div>
  </div>
</template>
