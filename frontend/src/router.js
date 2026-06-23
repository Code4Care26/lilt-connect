import { createRouter, createWebHistory } from 'vue-router'
import ConsoleView from './views/ConsoleView.vue'
import EventsView from './views/EventsView.vue'
import CandidatureView from './views/CandidatureView.vue'
import NewEventView from './views/NewEventView.vue'
import ProfileView from './views/ProfileView.vue'
import VolunteerStreamView from './views/VolunteerStreamView.vue'
import VolunteerEventDetailView from './views/VolunteerEventDetailView.vue'
import MyApplicationsView from './views/MyApplicationsView.vue'
import StatesLegendView from './views/StatesLegendView.vue'
import VolunteerProfileView from './views/VolunteerProfileView.vue'
import SupporterStreamView from './views/SupporterStreamView.vue'
import SupporterEventDetailView from './views/SupporterEventDetailView.vue'
import SupporterMyEventsView from './views/SupporterMyEventsView.vue'
import SupporterProfileView from './views/SupporterProfileView.vue'
import LoginView from './views/LoginView.vue'
import { useSessionStore } from './stores/session'

const ROLE_HOME = { staff: '/events', volunteer: '/volunteer/events', supporter: '/supporter/events' }

// Each route maps to one frame of the Staff design canvas. Navigation
// mirrors the flows drawn there: Eventi → Gestisci candidature, and
// Eventi → Nuovo → form. The cancel-reason sheet is a modal rendered on
// top of the Eventi view, so it has no route of its own.
const routes = [
  // Land on the active role's home (default role is supporter).
  { path: '/', redirect: () => ROLE_HOME[useSessionStore().role] || '/supporter/events' },

  // Staff
  { path: '/console', name: 'console', component: ConsoleView, meta: { role: 'staff' } },
  { path: '/events', name: 'events', component: EventsView, meta: { role: 'staff' } },
  { path: '/events/new', name: 'new-event', component: NewEventView, meta: { role: 'staff', hideNav: true } },
  { path: '/events/:id/edit', name: 'edit-event', component: NewEventView, props: true, meta: { role: 'staff', hideNav: true } },
  { path: '/events/:id/applications', name: 'applications', component: CandidatureView, props: true, meta: { role: 'staff' } },
  { path: '/profile', name: 'profile', component: ProfileView, meta: { role: 'staff', hideNav: true } },

  // Volunteer
  { path: '/volunteer/events', name: 'volunteer-events', component: VolunteerStreamView, meta: { role: 'volunteer' } },
  { path: '/volunteer/events/:id', name: 'volunteer-event', component: VolunteerEventDetailView, props: true, meta: { role: 'volunteer', hideNav: true } },
  { path: '/volunteer/applications', name: 'volunteer-applications', component: MyApplicationsView, meta: { role: 'volunteer' } },
  { path: '/volunteer/states', name: 'volunteer-states', component: StatesLegendView, meta: { role: 'volunteer', hideNav: true } },
  { path: '/volunteer/profile', name: 'volunteer-profile', component: VolunteerProfileView, meta: { role: 'volunteer', hideNav: true } },

  // Supporter
  { path: '/supporter/events', name: 'supporter-events', component: SupporterStreamView, meta: { role: 'supporter' } },
  { path: '/supporter/events/:id', name: 'supporter-event', component: SupporterEventDetailView, props: true, meta: { role: 'supporter', hideNav: true } },
  { path: '/supporter/mine', name: 'supporter-mine', component: SupporterMyEventsView, meta: { role: 'supporter' } },
  { path: '/supporter/login', name: 'supporter-login', component: LoginView, meta: { role: 'supporter', hideNav: true } },
  { path: '/supporter/profile', name: 'supporter-profile', component: SupporterProfileView, meta: { role: 'supporter', hideNav: true } },
]

export default createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})
