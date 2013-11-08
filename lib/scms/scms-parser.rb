module Scms
	require 'scms/scms-utils.rb'

	require 'erb'
    require 'ostruct' 

	class ScmsParser
		attr_accessor :template, :model

		def template= template
			@template = template
		end

		def model= model
			@model = model
		end

		def initialize (template, model = Hash.new)
			@template = template  

			if model.class == OpenStruct 
				@model = model
			else
				@model = OpenStruct.new(model.clone)
			end
		end

	    def parse(viewpath = nil)
	        result = ""
	        if @template != nil
	            begin 
	                page = @model 
	                erb = ERB.new(@template)
	                result = erb.result(page.instance_eval { binding })
	                result = result.encode('UTF-8', :invalid => :replace, :undef => :replace)

	                # only do cms click edit on sub views not layout templates
	                if page.view != nil
	                    if page.mode == "cms"
							if viewpath != nil
								result = "<div class='cms' data-view='#{viewpath}' data-page='#{page.url}'>#{result}</div>" if page.allowEdit
							end
	                    end
	                end
	                
	            rescue StandardError => e
	                #puts "page: #{page}"
	                ScmsUtils.errLog("Critical Error: Could not parse template")
	                #ScmsUtils.errLog(e.message)

	                result = "<div style='border: 1px solid #A8A8A8; border-radius:8px; background-color: #FFFFE0; box-shadow: 5px 5px 3px #CDCDCD; padding: 15px; margin: 15px;'>"
	                result += "<p>Critical Error: Could not parse template</p>"
	                result += "<code><pre>"
	                result += e.message
	                result += "\n\n"
	                result += e.inspect

	                result += "\n\n"
	                result += "Valid Template Keys are:\n"
	                @model.marshal_dump.each do |key, value|
	                    result += "- page.#{key}\n"
	                    puts "nil value foy key: #{key}" if value == nil
	                    singleton_class.send(:define_method, key) { value }
	                end
	                result += "\n\n"
	                result += e.backtrace.join("\n")
	                result += "</pre></code></div>"
	                result += "\n\n"
	                result += template

	            rescue Exception => e  
	                puts "Problem with template - check property exists"
	            end
	        else
	            ScmsUtils.log("Error: Can not parse template.  Template is empty")
	        end
	        
	        return result
	    end
	end
end