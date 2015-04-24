class Pingpong < Thor
  include Thor::Actions

  desc "setup", "Creates the initial migration for checks and applies it."
  def setup
    # lets create the migration file
    t = Time.new()
    fileName = "db/migrate/#{t.strftime("%Y%m%d%H%M%S")}_create_checks_and_incidents.rb"

    create_file fileName do
<<TEMPLATE
class CreateChecksAndIncidents < ActiveRecord::Migration
  def change
    create_table(:checks) do |t|
      t.string :name
      t.string :url
      t.integer :frequency
      t.string :method
      t.text :headers
      t.text :data
      t.boolean :save_body
      t.string :http_username
      t.string :http_password

      t.text :custom_properties
      t.text :incident_checking
      t.text :configurations, :default => '{"email_warn":false, "email_bad":true}'

      t.timestamps
    end

    add_index :checks, :name, unique: true

    create_table(:incidents) do |t|
      t.integer :check_id
      t.integer :incident_type
      t.text :info
      t.text :check_response

      t.timestamps
    end

    add_index :incidents, :check_id
  end
end
TEMPLATE
    end unless File.exists?(fileName)

    run("bundle exec rake db:migrate")
  end

  def self.source_root
    File.dirname(__FILE__)
  end
end
