<script setup>
import { computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useStaffStore } from '../stores/staff'
import { useUiStore } from '../stores/ui'
import { downloadParticipantsCsv } from '../lib/eventExport'
import LucideIcon from '../components/ui/LucideIcon.vue'
import Avatar from '../components/ui/Avatar.vue'
import ProgressBar from '../components/ui/ProgressBar.vue'
import ContactActions from '../components/ContactActions.vue'

// Frame 2 of the design: manage volunteer applications for one event —
// approve, move to waitlist, or reject. Capacity card up top. The applications
// are the real volunteer candidatures for this event, loaded on open. This is
// also the staff "show evento" surface: it carries the Modifica and Esporta
// partecipanti actions, and each applicant row exposes call/WhatsApp/email.
const props = defineProps({ id: { type: String, required: true } })
const router = useRouter()
const store = useStaffStore()
const ui = useUiStore()

const event = computed(() => store.eventById(props.id))

onMounted(() => store.loadApplicants(props.id))
watch(() => props.id, (id) => store.loadApplicants(id))

const goEdit = () => router.push(`/events/${props.id}/edit`)

function exportParticipants() {
  const ok = downloadParticipantsCsv(event.value, store.applicants)
  ui.showToast(ok ? 'Elenco partecipanti esportato.' : 'Nessun partecipante da esportare.', ok ? 'ok' : 'info')
}
</script>

<template>
  <div class="flex h-full flex-col">
    <!-- Header with back -->
    <header class="flex flex-none items-center gap-3 border-b border-line bg-white px-[18px] pb-3.5 pt-1.5">
      <button
        class="flex h-[38px] w-[38px] flex-none cursor-pointer items-center justify-center rounded-full bg-[#F1F5F9]"
        @click="router.push('/events')"
      >
        <LucideIcon name="ChevronLeft" :size="20" :stroke-width="2.2" color="#0F172A" />
      </button>
      <div class="min-w-0 flex-1">
        <div class="truncate text-[17px] font-bold leading-tight tracking-tight text-ink">
          {{ event ? event.title : 'Evento' }}
        </div>
        <div class="mt-0.5 text-xs font-medium leading-tight text-muted">
          {{ event ? event.dateLabel : '' }} · candidature volontari
        </div>
      </div>
      <button
        class="flex h-[38px] w-[38px] flex-none cursor-pointer items-center justify-center rounded-full bg-[#F1F5F9] text-[#334155] transition-colors hover:bg-[#E2E8F0]"
        title="Modifica evento"
        @click="goEdit"
      >
        <LucideIcon name="PencilLine" :size="18" :stroke-width="2.2" />
      </button>
      <button
        class="flex h-[38px] w-[38px] flex-none cursor-pointer items-center justify-center rounded-full bg-[#F1F5F9] text-[#334155] transition-colors hover:bg-[#E2E8F0] disabled:cursor-not-allowed disabled:opacity-40"
        title="Esporta partecipanti"
        :disabled="store.applicants.length === 0"
        @click="exportParticipants"
      >
        <LucideIcon name="Download" :size="18" :stroke-width="2.2" />
      </button>
    </header>

    <div class="scrl flex-1 overflow-y-auto px-4 pb-[calc(96px+env(safe-area-inset-bottom))] pt-4">
      <!-- Capacity card -->
      <div class="mb-[18px] rounded-2xl border border-line bg-white p-[15px] shadow-[0_1px_3px_0_rgba(15,23,42,.08)]">
        <div class="mb-2.5 flex items-baseline justify-between">
          <span class="text-[13px] font-semibold text-ink">Volontari approvati</span>
          <span class="text-sm font-bold text-brand-dark">{{ store.approvedCount }} / {{ store.capacity }}</span>
        </div>
        <ProgressBar :pct="store.fillPct" />
        <div class="mt-2.5 flex gap-3.5">
          <span class="text-xs font-medium text-[#B45309]">{{ store.pendingCount }} in attesa</span>
          <span class="text-xs font-medium text-[#1D4ED8]">{{ store.waitCount }} in riserva</span>
        </div>
      </div>

      <!-- Pending -->
      <template v-if="store.pendingCount > 0">
        <div class="mx-0.5 mb-2.5 flex items-center gap-1.5">
          <span class="text-[11px] font-bold uppercase leading-none tracking-wider text-[#B45309]">In attesa</span>
          <span class="text-[11px] font-semibold text-faint">{{ store.pendingCount }}</span>
        </div>
        <div class="mb-5 flex flex-col gap-2.5">
          <div
            v-for="p in store.pendingList"
            :key="p.id"
            class="rounded-[13px] border border-line bg-white p-3 shadow-[0_1px_2px_0_rgba(15,23,42,.06)]"
          >
            <div class="flex items-center gap-2.5">
              <Avatar :initials="p.initials" :color="p.color" />
              <div class="min-w-0 flex-1">
                <div class="text-sm font-semibold leading-tight text-ink">{{ p.name }}</div>
                <div class="mt-0.5 text-xs font-medium leading-tight text-muted">{{ p.pref }}</div>
              </div>
            </div>
            <div class="mt-2.5 flex gap-2">
              <button
                class="flex h-10 flex-1 items-center justify-center gap-1.5 rounded-[10px] bg-brand text-[12.5px] font-semibold text-white transition-colors hover:bg-brand-dark"
                @click="store.approve(p.id, p.name)"
              >
                <LucideIcon name="Check" :size="15" :stroke-width="2.4" color="#fff" />
                Approva
              </button>
              <button
                class="h-10 flex-none rounded-[10px] border border-line bg-white px-3.5 text-[12.5px] font-semibold text-[#1D4ED8] transition-colors hover:border-[#BFDBFE] hover:bg-[#EFF6FF]"
                @click="store.moveToWaitlist(p.id, p.name)"
              >
                Riserva
              </button>
              <button
                class="flex h-10 w-10 flex-none items-center justify-center rounded-[10px] border border-line bg-white text-faint transition-colors hover:border-[#FECACA] hover:bg-[#FEF2F2] hover:text-[#DC2626]"
                @click="store.reject(p.id, p.name)"
              >
                <LucideIcon name="X" :size="16" :stroke-width="2.2" />
              </button>
            </div>
            <ContactActions class="mt-2" :phone="p.phone" :email="p.email" />
          </div>
        </div>
      </template>

      <!-- Approved -->
      <template v-if="store.approvedCount > 0">
        <div class="mx-0.5 mb-2.5 flex items-center gap-1.5">
          <span class="text-[11px] font-bold uppercase leading-none tracking-wider text-[#15803D]">Approvati</span>
          <span class="text-[11px] font-semibold text-faint">{{ store.approvedCount }}</span>
        </div>
        <div class="mb-5 flex flex-col gap-2.5">
          <div
            v-for="p in store.approvedList"
            :key="p.id"
            class="rounded-[13px] border border-line bg-white px-3 py-2.5"
          >
            <div class="flex items-center gap-2.5">
              <Avatar :initials="p.initials" :color="p.color" :size="38" />
              <div class="min-w-0 flex-1">
                <div class="text-[13.5px] font-semibold leading-tight text-ink">{{ p.name }}</div>
                <div class="mt-px text-[11.5px] font-medium leading-tight text-muted">{{ p.pref }}</div>
              </div>
              <span class="flex h-[26px] w-[26px] flex-none items-center justify-center rounded-full border border-[#BBF7D0] bg-[#F0FDF4]">
                <LucideIcon name="Check" :size="14" :stroke-width="2.6" color="#15803D" />
              </span>
              <button
                class="flex h-[34px] w-[34px] flex-none items-center justify-center rounded-[9px] border border-line bg-white text-faint transition-colors hover:border-[#BFDBFE] hover:bg-[#EFF6FF] hover:text-[#1D4ED8]"
                title="Sposta in riserva"
                @click="store.moveToWaitlist(p.id, p.name)"
              >
                <LucideIcon name="ArrowDownUp" :size="15" :stroke-width="2.2" />
              </button>
            </div>
            <ContactActions class="mt-2" :phone="p.phone" :email="p.email" />
          </div>
        </div>
      </template>

      <!-- Waitlist -->
      <template v-if="store.waitCount > 0">
        <div class="mx-0.5 mb-2.5 flex items-center gap-1.5">
          <span class="text-[11px] font-bold uppercase leading-none tracking-wider text-[#1D4ED8]">Lista di riserva</span>
          <span class="text-[11px] font-semibold text-faint">{{ store.waitCount }}</span>
        </div>
        <div class="flex flex-col gap-2.5">
          <div
            v-for="p in store.waitList"
            :key="p.id"
            class="rounded-[13px] border border-line bg-white px-3 py-2.5"
          >
            <div class="flex items-center gap-2.5">
              <Avatar :initials="p.initials" :color="p.color" :size="38" />
              <div class="min-w-0 flex-1">
                <div class="text-[13.5px] font-semibold leading-tight text-ink">{{ p.name }}</div>
                <div class="mt-px text-[11.5px] font-medium leading-tight text-muted">{{ p.pref }}</div>
              </div>
              <button
                class="h-9 flex-none rounded-[10px] bg-brand px-3.5 text-[12.5px] font-semibold text-white transition-colors hover:bg-brand-dark"
                @click="store.approve(p.id, p.name)"
              >
                Approva
              </button>
            </div>
            <ContactActions class="mt-2" :phone="p.phone" :email="p.email" />
          </div>
        </div>
      </template>

      <!-- Withdrawn: shown for awareness (promote from the waitlist), not counted, no actions. -->
      <template v-if="store.withdrawnList.length > 0">
        <div class="mx-0.5 mb-2.5 flex items-center gap-1.5">
          <span class="text-[11px] font-bold uppercase leading-none tracking-wider text-[#64748B]">Ritirati</span>
          <span class="text-[11px] font-semibold text-faint">{{ store.withdrawnList.length }}</span>
        </div>
        <div class="mb-5 flex flex-col gap-2.5">
          <div
            v-for="p in store.withdrawnList"
            :key="p.id"
            class="flex items-center gap-2.5 rounded-[13px] border border-line bg-[#F8FAFC] px-3 py-2.5"
          >
            <Avatar :initials="p.initials" :color="p.color" :size="38" />
            <div class="min-w-0 flex-1">
              <div class="text-[13.5px] font-semibold leading-tight text-muted line-through">{{ p.name }}</div>
            </div>
            <span class="inline-flex h-[26px] items-center gap-1.5 rounded-full border border-[#E2E8F0] bg-white px-2.5">
              <LucideIcon name="LogOut" :size="13" :stroke-width="2.2" color="#64748B" />
              <span class="text-[11px] font-semibold leading-none text-[#64748B]">Ritirato</span>
            </span>
          </div>
        </div>
      </template>

      <p v-if="store.applicants.length === 0" class="py-10 text-center text-sm text-faint">
        Nessuna candidatura per questo evento.
      </p>
    </div>
  </div>
</template>
