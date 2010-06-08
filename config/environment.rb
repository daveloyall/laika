# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

# Ensure that Saxon is used for running XSLT. For this to work, the Saxon jars must be included in the
# CLASSPATH environment variable. Using require to pull them in does not seem to work.
java.lang.System.setProperty("javax.xml.transform.TransformerFactory","net.sf.saxon.TransformerFactoryImpl")
java.lang.System.setProperty("javax.xml.parsers.DocumentBuilderFactory","net.sf.saxon.dom.DocumentBuilderFactoryImpl")

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified
  # here.  Application configuration should go into files in
  # config/initializers -- all .rb files in that directory are automatically
  # loaded.  See Rails::Configuration for more options.

  # Skip frameworks you're not going to use (only works if using
  # vendor/rails).  To use Rails without a database, you must remove the
  # Active Record framework
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Only load the plugins named here, in the order given. By default, all
  # plugins in vendor/plugins are loaded in alphabetical order.  :all can be
  # used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use SQL instead of Active Record's schema dumper when creating the test
  # database.  This is necessary if your schema can't be completely dumped by
  # the schema dumper, like if you have constraints or database-specific
  # column types
  # config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector
  config.active_record.observers = :user_observer

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc

  # These are dependencies we need to run the application.
  config.gem 'faker',                :version => '0.3.1'
  config.gem 'calendar_date_select', :version => '1.15'
  config.gem 'mislav-will_paginate', :version => '>= 2.3.6', :lib => 'will_paginate', :source => 'http://gems.github.com'

  # These are declared as dependencies of the CCHIT-xds-facade gem but
  # they're not being automatically installed during rake gems:install. This
  # is because GitHub is specified as the sole gem source so dependencies are
  # not found.
  config.gem 'uuid', :version => '2.0.1'
  config.gem 'builder', :version => '2.1.2'
  config.gem 'CCHIT-xds-facade', :lib => 'xds-facade', :version => '>= 0.1.1', :source => 'http://gems.github.com'
  config.gem 'state_machine'

  # Setting a default timezone, please change this to where ever you are
  # deployed
  config.time_zone = "Eastern Time (US & Canada)"

  # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
  # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}')]
  # config.i18n.default_locale = :de
end

ENV['HOST_URL'] = 'http://demo.cchit.org/laika'
ENV['HELP_LIST'] = 'talk@projectlaika.org'
