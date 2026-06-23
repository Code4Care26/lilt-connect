# Be sure to restart your server when you modify this file.

# Avoid CORS issues when the LILT PWA (frontend/) calls this API from the Vite
# dev server. For the hackathon we allow the local dev origins; tighten this to
# the real deploy origin(s) before any production use.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "http://localhost:5173", "http://127.0.0.1:5173", "http://192.168.1.66:5173"

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
