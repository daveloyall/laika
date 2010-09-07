if Laika.use_atna

class AtnaAudit < ActiveRecord::Base
  establish_connection "syslog"
  set_table_name "entry_element"
end

end
