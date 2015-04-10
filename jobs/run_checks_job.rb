require 'pushpop'
require 'pushpop-keen'
require 'pushpop-sendgrid'

require 'dotenv'
Dotenv.load

require 'sinatra'
require 'sinatra/activerecord'
set :database_file, File.dirname(__FILE__) + "/../database.yml"

require './pingpong_config'
config = PingpongConfig

require File.dirname(__FILE__) + "/../lib/check.rb"

KEEN_COLLECTION = ENV['KEEN_COLLECTION'] || 'checks'

job do

  every 1.minute

  step 'get checks to process' do
    time = Time.now
    minute = time.min + (time.hour * 60)

    Check.all.reject{|check| minute % check.frequency != 0}
  end

  step 'run checks' do |checks|
    checks_with_incidents = []

    checks.each do |check|
      check_response = nil

      begin
        config.check_runner.run_check(config, check) do |start_time, duration, response|
          #log_check(config, check, start_time, duration, response)
          check_response = response
          config.logger.info("CheckComplete, #{check.name}, #{duration}")
          config.logger.debug(response)

          if check_response[:had_incident]
            checks_with_incidents.push(check)
          end

          begin
            config.check_logger.log(config,
                                    check,
                                    config.check_marshaller.to_properties(
                                        config, check, start_time, duration, response))
          rescue => e
            config.logger.error("CheckLoggingFailed for #{check.name}")
            config.logger.error(e)
          end
        end
      rescue => e
        config.logger.info("Check running failed for #{check.name}.")
        config.logger.debug(check_response)
      end
    end

    checks_with_incidents
  end

  step 'send emails' do |response, step_responses|
    config.logger.info("Checks with incidents: #{response.length}")

    if !response.empty?
      response.each do |check|
        config.logger.info("Doing check '#{check.name}'.")
        if (check.is_bad? && check.email_bad?) || (check.is_warn? && check.email_warn?)
          config.logger.info("Should send.")
          # things here
          incident = Incident.most_recent_for_check(check, 1).first
          subject = incident.email_subject
          message = incident.email_body

          send_email(config.to_email_address, config.from_email_address, subject, message)
        end
      end
    end
  end
end
