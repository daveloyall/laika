class Result < AbstractResult

  def statement_c32_template_id
    '2.16.840.1.113883.3.88.11.83.15.1'
  end

  def statement_ihe_template_id
    '1.3.6.1.4.1.19376.1.5.3.1.4.13'
  end

  def self.c32_component(results, xml)
    # Start Results
    unless results.empty?
      xml.component do
        xml.section do
          xml.templateId("root" => "2.16.840.1.113883.10.20.1.14", 
                         "assigningAuthorityName" => "CCD")
          xml.code("code" => "30954-2", 
                   "displayName" => "Relevant diagnostic tests", 
                   "codeSystem" => "2.16.840.1.113883.6.1", 
                   "codeSystemName" => "LOINC")
          xml.title("Results")
          xml.text do
            xml.table("border" => "1", "width" => "100%") do
              xml.thead do
                xml.tr do
                  xml.th "Result ID"
                  xml.th "Result Date"
                  xml.th "Result Display Name"
                  xml.th "Result Value"
                  xml.th "Result Unit"
                  xml.th "Result Free Text"
                end
              end
              xml.tbody do
                results.each do |result|
                  xml.tr do 
                    xml.td(result.result_id)
                    xml.td(result.result_date)
                    xml.td(result.result_code_display_name)
                    xml.td(result.value_scalar)
                    xml.td(result.value_unit)
                    xml.td do
                      xml.content("#{result.result_code_display_name}: #{result.value_scalar} #{result.value_unit}", "ID" => c32_abstract_result_id)
                    end
                  end
                end
              end
            end

          end

          yield


        end
      end
    end
    # End Results
  end


end
