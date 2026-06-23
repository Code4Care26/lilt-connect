# The dataset lives in app/services/seeds.rb (autoloaded, shared with POST
# /api/reset). This entrypoint just runs it for `bin/rails db:seed`.
Seeds.run!
puts "Seeded: #{Event.count} events, " \
     "#{EventApplication.count} applications, #{Participation.count} participations."
