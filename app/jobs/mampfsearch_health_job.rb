class MampfsearchHealthJob
  include Sidekiq::Worker

  sidekiq_options retry: false # job will be discarded if it fails

  def perform
    MampfsearchHealth.new.call
  end
end
