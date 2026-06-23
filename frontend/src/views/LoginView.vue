<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
import LucideIcon from '../components/ui/LucideIcon.vue'

// Magic-link login simulation (Readme §10): the user types a name and the
// backend "authenticates" by deriving the role from it. Login is immediate.
// Convention (prototype): a name ending in "staff" -> staff, in "vol" ->
// volunteer, anything else -> supporter.
const router = useRouter()
const session = useSessionStore()

const HOME = { staff: '/events', volunteer: '/volunteer/events', supporter: '/supporter/events' }

const name = ref('')
const busy = ref(false)

async function sendMagicLink() {
  const value = name.value.trim()
  if (!value || busy.value) return
  busy.value = true
  try {
    await session.login(value)
    router.push(HOME[session.role] || '/supporter/events')
  } finally {
    busy.value = false
  }
}

const continueGuest = () => router.push('/supporter/events')
</script>

<template>
  <div class="flex h-full flex-col bg-white">
    <div class="flex-none px-5 pt-1.5">
      <button
        class="flex h-[38px] w-[38px] cursor-pointer items-center justify-center rounded-full bg-[#F1F5F9]"
        @click="continueGuest"
      >
        <LucideIcon name="ChevronLeft" :size="20" :stroke-width="2.2" color="#0F172A" />
      </button>
    </div>

    <div class="scrl flex-1 overflow-y-auto px-6 pb-6 pt-5">
      <span class="text-[34px] font-extrabold leading-none tracking-wide text-lilt">LILT</span>
      <div class="mb-1.5 mt-[22px] text-2xl font-bold tracking-tight text-ink">Accedi</div>
      <p class="mb-6 text-sm leading-relaxed text-muted">
        Inserisci il tuo nome e ti inviamo un link di accesso. Entri subito e ritrovi le tue adesioni.
      </p>

      <label class="mb-1.5 block text-[13px] font-semibold text-[#334155]">Nome utente</label>
      <div class="mb-3 flex h-[50px] items-center gap-2.5 rounded-xl border border-[#CBD5E1] px-3.5">
        <LucideIcon name="User" :size="18" color="#94A3B8" />
        <input
          v-model="name"
          type="text"
          placeholder="Es. Giulia"
          class="w-full bg-transparent text-sm text-ink outline-none placeholder:text-faint"
          @keyup.enter="sendMagicLink"
        />
      </div>
      <p class="mb-5 text-xs leading-relaxed text-faint">
        Suggerimento demo: un nome che finisce con <span class="font-semibold text-muted">vol</span> entra come
        volontario, con <span class="font-semibold text-muted">staff</span> come staff, altrimenti come simpatizzante.
      </p>

      <button
        class="flex h-[52px] w-full cursor-pointer items-center justify-center gap-2.5 rounded-[13px] bg-brand text-[15px] font-bold text-white transition-colors hover:bg-brand-dark disabled:opacity-50"
        :disabled="!name.trim() || busy"
        @click="sendMagicLink"
      >
        <LucideIcon name="Mail" :size="18" color="#FFFFFF" />
        Invia magic link
      </button>

      <div class="mt-3.5 text-center">
        <span class="cursor-pointer text-[13.5px] font-medium text-faint" @click="continueGuest">Continua come ospite</span>
      </div>
    </div>
  </div>
</template>
