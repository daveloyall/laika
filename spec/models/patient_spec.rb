require File.dirname(__FILE__) + '/../spec_helper'

describe Patient, "with no fixtures" do

  it "should create a random patient without errors" do
    lambda { Patient.new.randomize }.should_not raise_error
  end

  it "should provide a hash of a c32 associations" do
    Patient.c32_modules.should == {
      :languages => :languages,
      :healthcare_providers => :providers,
      :medications => :medications,
      :allergies => :allergies,
      :insurance_providers => :insurance_providers,
      :conditions => :conditions,
      :vital_signs => :vital_signs,
      :test_results => :results,
      :immunizations => :immunizations,
      :encounters => :encounters,
      :procedures => :procedures,
      :medical_equipment => :medical_equipments,
      :personal_information => :registration_information,
      :support => :support,
      :information_source => :information_source,
      :advanced_directive => :advance_directive,
    }
  end

end

describe Patient, "from factory" do
  before(:each) do
    @patient = Patient.factory.new
  end

  describe "with no registration information" do
    it "should provide source_patient_info without errors" do
      @patient.source_patient_info.should be_kind_of(Hash)
    end
  end

  describe "with gender and date of birth registration information" do
    before do
      @patient.registration_information = @registration_information = RegistrationInformation.factory.new(:gender => @gender = Gender.factory.new, :date_of_birth => Date.today)
    end

    it "should provide source_patient_info" do
      @patient.source_patient_info.should == {
        :name => @patient.name,
        :gender => @gender.code,
        :date_of_birth => Date.today.to_s(:brief),
        :source_patient_identifier => nil,
      }
    end
  end
end

describe Patient, "with joe smith" do
  fixtures :patients, :registration_information, :person_names, :addresses, :telecoms, :genders, :patient_identifiers
  before(:each) do
     @patient = patients(:joe_smith) 
  end

  it "should require a name" do
    @patient.name = ''
    @patient.should_not be_valid
  end

  it "should return nothing when given a bad XDS id" do
      Patient.find_by_patient_identifier('abc').should be_nil
    end


   it "should return the found patient as a Laika model" do
    Patient.find_by_patient_identifier('1234567890^^^CCHIT&1.2.3.4.5.6.7.8.9&ISO').should_not be_nil
  end


  describe "copied with clone" do
  
    before(:each) do
       @patient_copy = @patient.clone
    end
 
  
    it "should have the same name as its source" do
      @patient_copy.name.should == @patient.name
    end
    
    it "should have the same registration information as its source" do
      @patient_copy.registration_information.should_not be_nil
      @patient_copy.registration_information.gender.code.should ==
        @patient.registration_information.gender.code
      @patient_copy.registration_information.person_name.first_name.should ==
        @patient.registration_information.person_name.first_name
      @patient_copy.registration_information.person_name.last_name.should ==
        @patient.registration_information.person_name.last_name
    end
  end
end

describe Patient, "with built-in records" do
  patient_fixtures

  [ :david_carter, :emily_jones, :jennifer_thompson, :theodore_smith, :joe_smith, :will_haynes ].each do |patient|
    it "should round-trip validate #{patient} without errors or warnings" do
      record = patients(patient)
      document = REXML::Document.new(record.to_c32)
      record.validate_c32(document).should be_empty
    end
  end

  it "should validate different patients with errors" do
    patient1 = patients(:david_carter)
    patient2 = patients(:joe_smith)
    document1 = REXML::Document.new(patient1.to_c32)
    document2 = REXML::Document.new(patient2.to_c32)

    # validate themselves (no errors)
    patient1.validate_c32(document1).should be_empty
    patient2.validate_c32(document2).should be_empty

    # validate each other (has errors)
    patient2.validate_c32(document1).should_not be_empty
    patient1.validate_c32(document2).should_not be_empty
  end

  it "should fail to validate when medication entries differ" do
    pending "SF ticket 2101046"
    record = patients(:jennifer_thompson)
    document = REXML::Document.new(record.to_c32)
    record.medications.clear
    record.validate_c32(document).should_not be_empty
  end

  it "should validate identical patients with 3 conditions" do
    record = patients(:joe_smith)
    record.conditions.clear
    3.times do |i|
      record.conditions << Condition.new(
        :start_event => Date.today + i,
        :problem_name => "condition #{i}",
        :problem_type => ProblemType.find(:first)
      )
    end
    document = REXML::Document.new(record.to_c32)
    record.validate_c32(document).should be_empty
  end

  it "should refresh updated_at when a child record is updated" do
    record = patients(:david_carter)
    old_updated_at = record.updated_at
    record.conditions.first.update_attributes!(:problem_name => 'something else')
    record.reload
    record.updated_at.should > old_updated_at
  end


  describe "after a deep copy" do

    before do
      @original = patients(:jennifer_thompson)
      @copy = @original.clone
    end

    # has many
    %w[ languages providers medications allergies insurance_providers conditions
       immunizations encounters procedures medical_equipments patient_identifiers
       all_results
    ].each do |assoc|
      it "should copy #{assoc}" do
        @original.send(assoc).count.should  == @copy.send(assoc).count
        # XXX ideally the patient would have at least one of every association
        if @original.send(assoc).count > 0
          @original.send(assoc).to_set.should_not == @copy.send(assoc).to_set
        end
      end
    end
  
    # has one
    %w[
      registration_information support information_source advance_directive
    ].each do |assoc|
      it "should copy #{assoc}" do
        @copy.send(assoc).should_not be_nil
        @original.send(assoc).should_not == @copy.send(assoc)
      end
    end
  end
end

