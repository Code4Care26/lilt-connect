<script setup>
import { useRouter } from 'vue-router'
import { VOLUNTEER_APP_META } from '../data/meta'
import LucideIcon from '../components/ui/LucideIcon.vue'

// Frame 4 of the volunteer design: a static legend explaining the application
// lifecycle. Colours/icons are reused from VOLUNTEER_APP_META for consistency.
const router = useRouter()

const LEGEND = [
  { key: 'pending', title: 'In attesa di approvazione', desc: 'Candidatura inviata. Puoi ritirarti in qualsiasi momento.' },
  { key: 'approved', title: 'Approvata', desc: 'Hai un posto confermato. Se non puoi più, devi tirare pacco.' },
  { key: 'waitlist', title: 'In lista di riserva', desc: 'Subentri se un approvato rinuncia. Puoi ritirarti liberamente.' },
  { key: 'supporter', title: 'Sostenitore', desc: 'Partecipi senza ruolo attivo. Nessuna approvazione necessaria.' },
].map((r) => ({ ...r, meta: VOLUNTEER_APP_META[r.key] }))
</script>

<template>
  <div class="flex h-full flex-col">
    <header class="flex flex-none items-center gap-3 border-b border-line bg-white px-[18px] pb-3.5 pt-1.5">
      <button
        class="flex h-[38px] w-[38px] flex-none cursor-pointer items-center justify-center rounded-full bg-[#F1F5F9]"
        @click="router.push('/volunteer/applications')"
      >
        <LucideIcon name="ChevronLeft" :size="20" :stroke-width="2.2" color="#0F172A" />
      </button>
      <div class="text-[17px] font-bold tracking-tight text-ink">Stati dell'adesione</div>
    </header>

    <div class="scrl flex-1 overflow-y-auto px-4 pb-10 pt-5">
      <div class="rounded-2xl border border-line bg-white p-5 shadow-[0_1px_3px_0_rgba(15,23,42,.08)]">
        <div class="text-base font-bold tracking-tight text-ink">Ciclo di un'adesione volontario</div>
        <p class="mb-[18px] mt-1 text-[13px] leading-relaxed text-muted">
          L'adesione non è automatica. Lo staff valuta e assegna lo stato.
        </p>

        <div class="flex flex-col gap-3.5">
          <div v-for="row in LEGEND" :key="row.key" class="flex gap-3">
            <div
              class="flex h-[34px] w-[34px] flex-none items-center justify-center rounded-[9px]"
              :style="{ background: row.meta.bg, border: `1px solid ${row.meta.border}` }"
            >
              <LucideIcon :name="row.meta.icon" :size="17" :stroke-width="2.2" :color="row.meta.fg" />
            </div>
            <div class="flex-1">
              <div class="text-sm font-semibold text-ink">{{ row.title }}</div>
              <div class="mt-0.5 text-[12.5px] leading-relaxed text-muted">{{ row.desc }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
