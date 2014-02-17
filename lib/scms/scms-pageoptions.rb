module Scms
  require 'fileutils'
  require 'scms/scms-utils.rb'

  class PageOptions
      attr_accessor :name, :template, :url, :title, :keywords, :description, :resource, :handler, :allowEdit

      def name= name  
        @name = name  
      end 

      def template= template  
        @template = template  
      end 

      def url= url  
        @url = url  
      end 

      def title= title  
        @title = title  
      end 

      def keywords= keywords  
        @keywords = keywords  
      end 

      def description= description  
        @description = description  
      end 

      def resource= resource
        @resource = resource
      end

      def handler= handler
        @handler = handler
      end

      def allowEdit= allowEdit
        @allowEdit = allowEdit
      end

      def initialize (name, website, pageconfig, siteConfig)  
        @name = name
        @template = siteConfig["template"]
        @url = "#{name}.html"
        @title = name
        @keywords = ""
        @description = ""
        @resource = Hash.new
        @handler = nil
        @allowEdit = true

        if pageconfig != nil
          @template = pageconfig["template"] unless pageconfig["template"] == nil
          
          @url = "#{name}/index.html" if pageconfig["cleanurl"] == true
          @url = pageconfig["generate"] if pageconfig["generate"] != nil #depreciated
          @url = pageconfig["url"] if pageconfig["url"] != nil

          @title = pageconfig["title"] unless pageconfig["title"] == nil
          @keywords = pageconfig["keywords"] if pageconfig["keywords"] != nil
          @description = pageconfig["description"] if pageconfig["description"] != nil
          @handler = pageconfig["handler"]
          @resource = getResource(website, pageconfig["resource"], pageconfig)
          @allowEdit = pageconfig["allowEdit"] if pageconfig["allowEdit"] != nil
        end
      end  

      
      def getResource(website, resource, config)
          ymlresource = Hash.new
          if resource != nil
              resourcepath = File.join(website, resource)
              if File.exists?(resourcepath)
                  #ScmsUtils.log( "_Resource found: #{pageOptions.resource}_" )
                  begin
                      ymlresource = YAML.load_file(resourcepath)
                  rescue Exception=>e
                      ScmsUtils.errLog(e.message)
                      ScmsUtils.log(e.backtrace.inspect)
                  end
              else
                  ScmsUtils.errLog("Resource not found: #{resource}")
                  ScmsUtils.writelog("::Resource not found #{resource}", website)
                  ScmsUtils.writelog("type NUL > #{resourcepath}", website)
              end
          else
            ymlresource = config
            ymlresource.delete("view")
            ymlresource.delete("views")
            ymlresource.delete("resource")
            ymlresource.delete("bundles")
            ymlresource.delete("navigation")
            ymlresource.delete("monkeyhook")
            ymlresource.delete("livereload")
          end
          return ymlresource
      end
  end
end