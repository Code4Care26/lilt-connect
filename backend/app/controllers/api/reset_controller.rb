module Api
  class ResetController < BaseController
    # POST /api/reset  -> mockDb.reset(); wipes back to the seed, returns true.
    def create
      Seeds.run!
      # Seeds.run! bypasses model callbacks (delete_all/insert_all), so emit one
      # invalidation for the whole wipe-and-reseed. Connected clients re-fetch.
      Realtime.publish(type: "reset")
      render json: true
    end
  end
end
