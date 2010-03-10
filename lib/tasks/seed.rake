namespace :db do

  desc "Load seed data into the current environment's database.  Seed data comes from spec/fixtures, and may be overridden on a file by file basis by fixtures placed in db/fixtures."
  task :seed => :environment do
    ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
    require 'active_record/fixtures'
    base_fixture_dir = File.join(RAILS_ROOT, 'spec/fixtures')
    overrides_fixture_dir = File.join(RAILS_ROOT, 'db/fixtures')
    fixtures = Dir.glob(File.join(base_fixture_dir, '*.yml')).inject({}) do |hash,f|
      hash[File.basename(f, '.yml')] = base_fixture_dir
      hash
    end
    Dir.glob(File.join(overrides_fixture_dir, '*.yml')).each do |f|
      fixtures[File.basename(f, '.yml')] = overrides_fixture_dir
    end
    fixtures.each do |fixture, directory|
      Fixtures.create_fixtures(directory, fixture)
    end
    if User.count == 0
      puts "You will now set up the administrator user."
      Rake::Task['db:create_admin'].invoke
    end
  end

  task :create_admin => :environment do
    loop do
      print "First name: "
      first = STDIN.gets.chomp
      print "Last name: "
      last = STDIN.gets.chomp
      print "Email address: "
      email = STDIN.gets.chomp
      print "Password: "
      password = STDIN.gets.chomp
      print "Confirm password: "
      password_confirmation = STDIN.gets.chomp
      begin
        u = User.create!(
          :first_name => first,
          :last_name => last,
          :email => email,
          :password => password,
          :password_confirmation => password_confirmation,
          :admin => true
        )
        puts "Created #{u}."
        break
      rescue ActiveRecord::RecordInvalid => e
        puts "Failed to create the administrator: #{e}."
      end
    end
  end
end
