import { httpApi } from './http'

// Single entry point for all data access. Stores import `api` from here and
// never touch the implementation directly. The backend (Rails) is the single
// source of truth — there is no offline mock — so the app requires the API to
// be reachable (in dev, through the Vite proxy at '/api').
export const api = httpApi
