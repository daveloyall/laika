# This is a patch for a YAML/Date formatting issue that arises if you have
# a :default date format set in your rails configuration.
#
# https://rails.lighthouseapp.com/projects/8994/tickets/340-yaml-activerecord-serialize-and-date-formats-problem
#
# ActiveSupport::CoreExtensions::Date::Conversions::DATE_FORMATS.merge!(:default => '%B %d, %Y')
#
# >> d = Date.today
# => Tue, 24 Aug 2010
# >> s = d.to_yaml
# => "--- !timestamp August 24, 2010\n"
# >> YAML.load(s)
# ArgumentError: argument out of range
#   from /usr/lib/ruby/1.8/yaml.rb:133:in `utc'
#   from /usr/lib/ruby/1.8/yaml.rb:133:in `node_import'
#   from /usr/lib/ruby/1.8/yaml.rb:133:in `load'
#   from /usr/lib/ruby/1.8/yaml.rb:133:in `load'
#   from (irb):4
# 
class Date
  def to_yaml( opts={} )      # modeled after yaml/rubytypes.rb in std library
    YAML::quick_emit( self, opts ) do |out|
      out.scalar( "tag:yaml.org,2002:timestamp", self.to_s(:db), :plain )
    end
  end
end
