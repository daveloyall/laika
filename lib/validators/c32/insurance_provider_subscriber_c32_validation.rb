 module InsuranceProviderSubscriberC32Validation


    include MatchHelper


    def validate_c32(act)

      unless act
        return [Laika::ValidationError.new]
      end

      errors = []

      begin
        particpantRole = REXML::XPath.first(act,"cda:participant[@typeCode='HLD']/cda:participantRole[@classCode='IND']",MatchHelper::DEFAULT_NAMESPACES)
        if person_name
          errors.concat person_name.validate_c32(REXML::XPath.first(particpantRole,"cda:playingEntity/cda:name",MatchHelper::DEFAULT_NAMESPACES))
        end       
        if address
          errors.concat address.validate_c32(REXML::XPath.first(particpantRole,'cda:addr',MatchHelper::DEFAULT_NAMESPACES))
        end
        if telecom
          errors.concat telecom.validate_c32(REXML::XPath.first(particpantRole,'cda:telecom',MatchHelper::DEFAULT_NAMESPACES))
        end
      rescue
        errors << Laika::ValidationError.new(
          :section => 'Subscriber Information', 
          :message => 'Failed checking name, address and telecom details on the insurance provider subcriber XML',
          :severity => 'error',
          :location => act.xpath
        )
      end

      return errors.compact
    end



  end
  
