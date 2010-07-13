require File.dirname(__FILE__) + '/../../spec_helper'

describe "C32 Healthcare Providers Validation" do
  fixtures :providers

  C32_HEALTHCARE_PROVIDERS = <<-EOS
<ClinicalDocument xmlns="urn:hl7-org:v3"
   xmlns:sdtc="urn:hl7-org:sdtc">
   <!-- These examples assume the default namespace is 'urn:hl7-org:v3' -->
   <documentationOf>
      <serviceEvent classCode="PCPR">
         <effectiveTime>
            <low value="19650120" />
            <high value="20070209" />
         </effectiveTime>
         <performer typeCode="PRF">
            <templateId root='2.16.840.1.113883.3.88.11.32.4' />
            <functionCode code='CP' displayName='Consulting Provider'
               codeSystem='2.16.840.1.113883.12.443'
               codeSystemName='Provider Role' />
            <originalText>Consulting Provider</originalText>
            <time>
               <low value="19770323" />
               <high value="19870323" />
            </time>
            <assignedEntity>
               <id root='78A150ED-B890-49dc-B716-5EC0027B3982'
                  extension="ProviderID" />
               <code code='370000000X'
                  displayName='Nursing Service Related Providers'
                  codeSystem='2.16.840.1.113883.6.101'
                  codeSystemName='ProviderCodes' />
               <addr>
                  <streetAddressLine>1234 Elm Street</streetAddressLine>
                  <city>Anytown</city>
                  <state>NY</state>
                  <postalCode>12345</postalCode>
                  <country>US</country>
               </addr>
               <telecom use="WP" value="tel:+1-555-555-1212"/>
               <assignedPerson>
                  <name>
                     <prefix>RN.</prefix>
                     <given>Mary</given>
                     <family>Smith</family>
                  </name>
               </assignedPerson>
               <sdtc:patient>
                  <sdtc:id root='78A150ED-B890-49dc-B716-5EC0027B3985'
                     extension='MedicalRecordNumber' />
               </sdtc:patient>
            </assignedEntity>
         </performer>
      </serviceEvent>
   </documentationOf>
</ClinicalDocument>
EOS
  
  before(:each) do
    @document = REXML::Document.new(C32_HEALTHCARE_PROVIDERS)
    @provider = providers(:rn_mary_smith)
    @scope = Validators::C32Validation::ComponentScope.new(
      :validation_type => Validation::C32_V2_5_TYPE,
      :logger => TestLoggerDevNull.new,
      :validator => "ComponentScopeTest",
      :inspection_type => "Testing",
      :component_module => :healthcare_providers,
      :reference_model => [@provider],
      :document => @document
    )
  end

  it "should validate the Healthcare Providers component" do
    @scope.validate.should == []
  end

  it "should fail if unable to match a performer section" do
    @provider.stub!(:first_name).and_return('foo')
    errors = @scope.validate
    errors.size.should == 1
    errors.first.should be_kind_of(Laika::NoMatchingSection)
    errors.first.location.should == '/ClinicalDocument/documentationOf/serviceEvent/performer'
    errors.first.expected_section.should == {
      :code => "CP",
      :name => "Consulting Provider",
      :assigned_entity_code => "370000000X",
      :assigned_entity_name => "Nursing Service Related Providers",
      :start_service => Date.new(1977,3,23),
      :end_service => Date.new(1987,3,23),
      :name_prefix => "RN.",
      :first_name => "foo",
      :middle_name => nil,
      :last_name => "Smith",
      :name_suffix => nil,
      :street_address_line_one => "1234 Elm Street",
      :street_address_line_two => nil,
      :city => "Anytown",
      :state => "NY",
      :postal_code => "12345",
      :iso_country => "US",
      :id => "78A150ED-B890-49dc-B716-5EC0027B3985",
    }
    errors.first.provided_sections.should == [
      {
        :code => "CP",
        :name => "Consulting Provider",
        :assigned_entity_code => "370000000X",
        :assigned_entity_name => "Nursing Service Related Providers",
        :start_service => "19770323",
        :end_service => "19870323",
        :name_prefix => "RN.",
        :first_name => "Mary",
        :middle_name => nil,
        :last_name => "Smith",
        :name_suffix => nil,
        :street_address_line_one => "1234 Elm Street",
        :street_address_line_two => nil,
        :city => "Anytown",
        :state => "NY",
        :postal_code => "12345",
        :iso_country => "US",
        :id => "78A150ED-B890-49dc-B716-5EC0027B3985",
      }
    ]

  end

  it "should have accurate expected and provided sections for unmatched telecom" do
    @provider.telecom.work_phone = '123-456-789' 
    errors = @scope.validate
    errors.size.should == 1
    errors.first.expected_section.should == {:use=>"WP", :value=>"123-456-789"}
    errors.first.provided_sections.should == [{:use=>"WP", :value=>"tel:+1-555-555-1212"}]
  end

end
