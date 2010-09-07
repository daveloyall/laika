module Laika

  # Set to true if you will be setting up an XDS database and making XDS
  # provide & register/query & retrieve tests
  # (Set in config/laika.yml)
  mattr_accessor :use_xds, :instance_writer => false
  @@use_xds = false

  # Set to true if you will be setting up a database for ATNA logging
  # (Set in config/laika.yml)
  mattr_accessor :use_atna, :instance_writer => false
  @@use_xds = false

  # Set to true if you will be performing PDQ/PIX testing
  # (Set in config/laika.yml)
  mattr_accessor :use_pix_pdq, :instance_writer => false
  @@use_xds = false

  # Set to true if you wish to test C62 documents
  # (Set in config/laika.yml)
  mattr_accessor :use_c62, :instance_writer => false
  @@use_xds = false

  TEST_PLAN_TYPES = {
    C32DisplayAndFilePlan.test_name     => C32DisplayAndFilePlan,
    NhinDisplayAndFilePlan.test_name    => NhinDisplayAndFilePlan,
    GenerateAndFormatPlan.test_name     => GenerateAndFormatPlan,
    PdqQueryPlan.test_name              => PdqQueryPlan,
    PixQueryPlan.test_name              => PixQueryPlan,
    PixFeedPlan.test_name               => PixFeedPlan,
    XdsProvideAndRegisterPlan.test_name => XdsProvideAndRegisterPlan,
    XdsQueryAndRetrievePlan.test_name   => XdsQueryAndRetrievePlan,
    C62InspectionPlan.test_name         => C62InspectionPlan,
  }

  module Constants
    STATES = %w[
      AK AL AR AS AZ CA CO CT DC DE FL FM GA GU HI IA ID IL IN KS KY LA MA
      MD ME MH MI MN MO MS MT NC NE NJ NH NM NV NY ND OH OK OR PA PW PR RI
      SC SD TN TX UT VI VT VA WA WI WV WY
    ]
  end
end
