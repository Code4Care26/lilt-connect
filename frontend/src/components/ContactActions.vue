<script setup>
import { computed } from 'vue'
import LucideIcon from './ui/LucideIcon.vue'

// Direct-contact shortcuts for one volunteer in the staff roster: call, WhatsApp,
// e-mail. Each is a plain anchor with the right scheme so the OS opens the dialer
// / WhatsApp / mail client. A button is rendered only when its datum is present.
const props = defineProps({
  phone: { type: String, default: '' },
  email: { type: String, default: '' },
})

// wa.me / tel: want a clean number; strip spaces, '+', dashes for the digits-only
// forms (the leading '+' is encoded by tel: anyway, but wa.me rejects it).
const digits = computed(() => (props.phone || '').replace(/\D/g, ''))
const telHref = computed(() => (props.phone ? `tel:${props.phone.replace(/\s/g, '')}` : null))
const waHref = computed(() => (digits.value ? `https://wa.me/${digits.value}` : null))
const mailHref = computed(() => (props.email ? `mailto:${props.email}` : null))
</script>

<template>
  <div class="flex gap-2">
    <a
      v-if="telHref"
      :href="telHref"
      title="Chiama"
      class="flex h-9 w-9 flex-none items-center justify-center rounded-[10px] border border-line bg-white text-[#0F766E] transition-colors hover:border-[#99F6E4] hover:bg-brand-tint"
    >
      <LucideIcon name="Phone" :size="16" :stroke-width="2.2" />
    </a>
    <a
      v-if="waHref"
      :href="waHref"
      target="_blank"
      rel="noopener"
      title="Scrivi su WhatsApp"
      class="flex h-9 w-9 flex-none items-center justify-center rounded-[10px] border border-line bg-white text-[#15803D] transition-colors hover:border-[#BBF7D0] hover:bg-[#F0FDF4]"
    >
      <LucideIcon name="MessageCircle" :size="16" :stroke-width="2.2" />
    </a>
    <a
      v-if="mailHref"
      :href="mailHref"
      title="Scrivi email"
      class="flex h-9 w-9 flex-none items-center justify-center rounded-[10px] border border-line bg-white text-[#1D4ED8] transition-colors hover:border-[#BFDBFE] hover:bg-[#EFF6FF]"
    >
      <LucideIcon name="Mail" :size="16" :stroke-width="2.2" />
    </a>
  </div>
</template>
