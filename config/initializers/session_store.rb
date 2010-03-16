# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_laika_session',
  :secret      => '681e432e138359a3334800969979c8c3c8cb84899d230702d26bbf730bada27f47d9cf4e1fab4c70af188df6a3a73b812e5c9588b57333faf998cd8e249384d9'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
ActionController::Base.session_store = :active_record_store
