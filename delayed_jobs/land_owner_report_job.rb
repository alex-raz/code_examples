class LandOwnerReportJob < ActiveJob::Base
  queue_as :default

  if Rails.env.test? || Rails.env.development?
    rescue_from ActiveJob::DeserializationError do |exception|
      # handle a deleted record
    end
  end

  def perform(object)
    LandOwnerReportSender.new.call(object)
  end
end
