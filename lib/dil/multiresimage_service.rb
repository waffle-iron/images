module DIL
  module MultiresimageService
    # include Hydra::AssetsControllerHelper
    # include Blacklight::SolrHelper

    # This method/web service is called from other applications (Orbeon VRA Editor, migration scripts).
    # The URL to call this method/web service is http://localhost:3000/multiresimages/create_update_fedora_object.xml
    # It's expecting a pid param in the URL (it will check the VRA xml in the xml), as well as VRA xml in the POST request.
    # This method will create or update a Fedora object using the VRA xml that's included in the POST request
    
    def create_update_fedora_object
      begin #for exception handling
       
        #default return xml
        returnXml = "<response><returnCode>403</returnCode></response>"
        #if request is coming from these IP's, all other ip's will return with the 403 error xml)
        if !request.remote_ip.nil? and !request.remote_ip.empty?
      
        #update returnXml (this is the error xml, will be updated if success)
        returnXml = "<response><returnCode>Error: The object was not saved.</returnCode><pid/></response>"
      
        #read in the xml from the POST request
        xml = request.body.read

        #make sure xml is not nil and not empty
        if !xml.nil? and !xml.empty? 
          #load xml into Nokogiri XML document
          document = Nokogiri::XML(xml)
          vra_type = ""
          pid = ""
          
          #pid might be a query param
          #debugger
          if !params[:pid].nil? and !params[:pid].empty?
            pid = params[:pid]
          end
          
          #determine if xml represents VRA work or VRA image by running xpath query and checking the result
          if !document.xpath("/vra:vra/vra:work").nil? and !document.xpath("/vra:vra/vra:work").empty?
            #debugger
            vra_type = "work"
            #attempt to extract the pid by running xpath query
            if pid.nil? or pid.empty?
              pid = document.xpath("/vra:vra/vra:work/@vra:refid", "vra"=>"http://www.vraweb.org/vracore4.htm").text
              if pid.nil? or pid.empty?
                pid = document.xpath("/vra:vra/vra:work/@refid", "vra"=>"http://www.vraweb.org/vracore4.htm").text
              end
            end
          elsif !document.xpath("/vra:vra/vra:image").nil? and !document.xpath("/vra:vra/vra:image").empty?
            #debugger
            vra_type = "image"
            #attempt to extract the pid by running xpath query
            if pid.nil? or pid.empty?
              pid = document.xpath("/vra:vra/vra:image/@vra:refid", "vra"=>"http://www.vraweb.org/vracore4.htm").text
              if pid.nil? or pid.empty?
                pid = document.xpath("/vra:vra/vra:image/@refid", "vra"=>"http://www.vraweb.org/vracore4.htm").text
              end
            end
          end
          
          #if no pid was in the xml, then create a new Fedora object
          if pid.nil? or pid.empty?
            #mint a pid
            pid = mint_pid()
            #if pid was minted successfully
            if !pid.nil? and !pid.empty?
            
              if vra_type == "image"
                #create Fedora object for VRA Image, calls method in helper
                #debugger
                returnXml = create_vra_image_fedora_object(pid, document)
              elsif vra_type == "work"
                #create Fedora object for VRA Work, calls method in helper
                #debugger
                returnXml = create_vra_work_fedora_object(pid, document)	           
              end
            
            end     
    
      
        #pid was in xml so update the existing Fedora object if the object exists, or create the object if it doesn't exist
          #(a pid might have been minted before this web service was called)
          else
            #if object doesn't exist in Fedora, create the object
            if ActiveFedora::Base.find(pid).nil?
              #create the object
              if vra_type == "image"
                returnXml = create_vra_image_fedora_object(pid, document)
              elsif vra_type == "work"
                returnXml = create_vra_work_fedora_object(pid, document)
              end
            else
              #object already exists, update the object
              returnXml = update_fedora_object(pid, xml, "VRA", "VRA")
            end
            
            #if a work, get a list of it's related images, and re-index those images (because work info
            #is indexed with the image, need to update the image index after the work index has been updated)
            if vra_type == "work"
              (solr_response, document_list) = get_related_images_from_controller(pid)
              document_list.each { |i|
                #load fedora object for the image
                fedora_object = ActiveFedora::Base.find(i.id, :cast=>true)
                #update it's solr index
                fedora_object.update_index()
              }
            end
         end #end pid if-else
      
         end #end xml_params if
     
       end #end request_ip if
    
     rescue ActiveFedora::ObjectNotFoundError
        #error xml
        returnXml = "<response><returnCode>Error: An object with that pid was not found in the repository.</returnCode><pid>" + pid + "</pid></response>"
        
      rescue Exception
        #error xml
        returnXml = "<response><returnCode>Error: The object was not saved.</returnCode><pid>" + pid + "</pid></response>"
        
      ensure #this will get called even if an exception was raised
        #respond to request with returnXml
        respond_with returnXml do |format|
          format.xml {render :layout => false, :xml => returnXml}
        end  
      end

    end #end method
    
    
    # This method/web service is called from other applications (migration scripts).
    # The URL to call this method/web service is http://localhost:3000/multiresimages/add_datastream.xml
    # It's expecting the following params in the URL: pid, ds_name, ds_label.  Also expecting xml in the POST request
    # This method will add a datastream to an existing Fedora object using the xml that's included in the POST request
    
    def add_datastream
      
      begin #for exception handling
        #default return xml
        returnXml = "<response><returnCode>403</returnCode></response>"
        
        if !request.remote_ip.nil? and !request.remote_ip.empty?
        #update returnXml (this is the error xml, will be updated if success)
        returnXml = "<response><returnCode>Error: The object was not saved.</returnCode><pid/></response>"
        #read in the xml from the POST request
        xml = request.body.read
        #make sure xml, pid, and datstream name and datastream label are not nil and not empty
        if !xml.nil? and !xml.empty? and !params[:pid].nil? and !params[:pid].empty? and !params[:ds_name].nil? and !params[:ds_name].empty? and !params[:ds_label].nil? and !params[:ds_label].empty?
            #calls method in helper
            returnXml = update_fedora_object(params[:pid], xml, params[:ds_name], params[:ds_label])
         end #end xml_params if
     
       end #end request_ip if
    
     rescue ActiveFedora::ObjectNotFoundError
        #error xml
        returnXml = "<response><returnCode>Error: An object with that pid was not found in the repository.</returnCode><pid>" + params[:pid] + "</pid></response>"
        
      rescue Exception
        #error xml
        returnXml = "<response><returnCode>Error: The object was not saved.</returnCode><pid>" + params[:pid] + "</pid></response>"
        
      ensure #this will get called even if an exception was raised
        #respond to request with returnXml
        respond_with returnXml do |format|
          format.xml {render :layout => false, :xml => returnXml}
        end  
      end

    end #end method
    
    
    # This method/web service is called from other applications (migration scripts).
    # The URL to call this method/web service is http://localhost:3000/multiresimages/add_external_datastream.xml
    # It's expecting the following params in the URL: pid, ds_name, ds_label, ds_location, mime_type.  Also expecting xml in the POST request
    # This method will create or update a Fedora object using the xml that's included in the POST request
    
    def add_external_datastream
      
      begin #for exception handling
        #default return xml
        returnXml = "<response><returnCode>403</returnCode></response>"
        if !request.remote_ip.nil? and !request.remote_ip.empty?
        #update returnXml (this is the error xml, will be updated if success)
        returnXml = "<response><returnCode>Error: The object was not saved.</returnCode><pid/></response>"
        #read in the xml from the POST request
        #xml = request.body.read
        #make sure pid, datstream name, datastream label and datastream location are not nil and not empty
        if !params[:pid].nil? and !params[:pid].empty? and !params[:ds_name].nil? and !params[:ds_name].empty? and !params[:ds_label].nil? and !params[:ds_label].empty? and !params[:ds_location].nil? and !params[:ds_location].empty? and !params[:mime_type].nil? and !params[:mime_type].empty?
            #calls method in helper
            returnXml = add_external_ds(params[:pid], params[:ds_name], params[:ds_label], params[:ds_location], params[:mime_type])
         end #end xml_params if
     
       end #end request_ip if
    
     rescue ActiveFedora::ObjectNotFoundError
        #error xml
        returnXml = "<response><returnCode>Error: An object with that pid was not found in the repository.</returnCode><pid>" + pid + "</pid></response>"
        
      rescue Exception
        #error xml
        returnXml = "<response><returnCode>Error: The object was not saved.</returnCode><pid>" + params[:pid] + "</pid></response>"
        
      ensure #this will get called even if an exception was raised
        #respond to request with returnXml
        respond_with returnXml do |format|
          format.xml {render :layout => false, :xml => returnXml}
        end  
      end

    end #end method
    
      
    # This method/web service is called from other applications (VRA Editor).
    # The URL to call this method/web service is http://localhost:3000/multiresimages/delete_fedora_object.xml
    # It's expecting the following params in the URL: pid.
    # This method will delete a Fedora object using the pid that's included in the request
    
    def delete_fedora_object
      
      begin #for exception handling
        #default return xml
        returnXml = "<response><returnCode>403</returnCode></response>"
         if !request.remote_ip.nil? and !request.remote_ip.empty?
        #update returnXml (this is the error xml, will be updated if success)
        returnXml = "<response><returnCode>Error: The object was not deleted.</returnCode><pid/></response>"
    
          if !params[:pid].nil? and !params[:pid].empty?
            fedora_object = ActiveFedora::Base.find(params[:pid], :cast=>true)
            fedora_object.delete
          returnXml = "<response><returnCode>Delete successful</returnCode><pid>" + params[:pid] + "</pid></response>"
            end
       
       end #end request_ip if
    
     rescue ActiveFedora::ObjectNotFoundError
        #error xml
        returnXml = "<response><returnCode>Error: An object with that pid was not found in the repository.</returnCode><pid>" + pid + "</pid></response>"
        
      rescue Exception
        #error xml
        returnXml = "<response><returnCode>Error: The object was not deleted.</returnCode><pid>" + params[:pid] + "</pid></response>"
        
      ensure #this will get called even if an exception was raised
        #respond to request with returnXml
        respond_with returnXml do |format|
          format.xml {render :layout => false, :xml => returnXml}
        end  
      end

    end #end method
    
    # This method/web service is called from other applications (VRA Editor).
    # The URL to call this method/web service is http://localhost:3000/multiresimages/clone_fedora_object.xml
    # It's expecting the following params in the URL: pid.
    # This method will clone a Fedora object using the pid that's included in the request
    
    def clone_work
      
      begin #for exception handling
        #default return xml
        
        returnXml = "<response><returnCode>403</returnCode></response>"
       
        if !request.remote_ip.nil? and !request.remote_ip.empty? 
        #update returnXml (this is the error xml, will be updated if success)
        returnXml = "<response><returnCode>Error: The object was not cloned.</returnCode><pid/></response>"
        
          if !params[:pid].nil? and !params[:pid].empty?
            
            pid = params[:pid]
          
        orig_fedora_object = ActiveFedora::Base.find(pid, :cast=>true)
          
        #mint a pid
        new_pid = mint_pid()
          
        # create new Fedora object with minted pid
        new_fedora_object = Vrawork.new({:pid=>new_pid})
          
        orig_xml = orig_fedora_object.datastreams["VRA"].content
    
        orig_document = Nokogiri::XML(orig_xml)
        orig_document.xpath("/vra:vra/vra:work/vra:relationSet").remove
        #orig_document.xpath("/vra:vra/vra:work/vra:locationSet").remove
          
        display = orig_document.xpath("/vra:vra/vra:work/vra:locationSet/vra:display").text
        display = display.gsub(/DIL:.*\s/,'DIL:' + new_pid + ' ; ')
        orig_document.xpath("/vra:vra/vra:work/vra:locationSet/vra:display")[0].content = display
          
        orig_document.xpath("/vra:vra/vra:work/vra:locationSet/vra:location/vra:refid[@source='DIL']").each do |node|
          node.content = new_pid
        end
          
        id_attr = orig_document.xpath("/vra:vra/vra:work/@id")
        id_attr[0].remove
          
        #set the refid attribute to the new pid
        orig_document.xpath("/vra:vra/vra:work", "vra"=>"http://www.vraweb.org/vracore4.htm").attr("refid", new_pid)
        #refid_attr = document.xpath("/vra:vra/vra:work/@refid")
        #refid_attr[0].value = new_pid
          
        new_fedora_object.datastreams["VRA"].content = orig_document.to_s
        new_fedora_object.save()
          
        returnXml = "<response><returnCode>Clone successful</returnCode><pid>" + new_pid + "</pid></response>"
        end #end if	
     
       end #end request_ip if
    
     rescue ActiveFedora::ObjectNotFoundError
        #error xml
        returnXml = "<response><returnCode>Error: An object with that pid was not found in the repository.</returnCode><pid>" + pid + "</pid></response>"
        
      rescue Exception
        #error xml
        returnXml = "<response><returnCode>Error: The object was not cloned.</returnCode><pid>" + pid + "</pid></response>"
        
      ensure #this will get called even if an exception was raised
        #respond to request with returnXml
        respond_with returnXml do |format|
          format.xml {render :layout => false, :xml => returnXml}
        end  
      end

    end #end method


    private

    def build_related_image_query(user_query)
      q = "#{user_query}"
      # Append the exclusion of FileAssets
      q << " AND NOT _query_:\"info\\\\:fedora/afmodel\\\\:FileAsset\""

      # Append the query responsible for adding the users discovery level
      permission_types = ["edit","discover","read"]
      field_queries = []
      permission_types.each do |type|
        field_queries << "_query_:\"#{type}_access_group_t:public\""
      end

      unless current_user.nil?
        # for roles
        RoleMapper.roles(current_user.login).each do |role|
          permission_types.each do |type|
            field_queries << "_query_:\"#{type}_access_group_t:#{role}\""
          end
        end
        # for individual person access
        permission_types.each do |type|
          field_queries << "_query_:\"#{type}_access_person_t:#{current_user.login}\""
        end
        if current_user.is_being_superuser?(session)
          permission_types.each do |type|
            field_queries << "_query_:\"#{type}_access_person_t:[* TO *]\""
          end
        end
      end
      q << " AND (#{field_queries.join(" OR ")})"
      q
    end


    #This method calls a method within Blacklight::SolrHelper.  It needs to invoked from a view helper, but the view helper can't invoke it
    #directly.  The view helper (multiresimage_helper) invokes this method, which invokes the get_search_results method in Blacklight::SolrHelper
    def get_solr_search_results(escaped_pid)
      (solr_response, document_list) = get_search_results(:q=>build_related_image_query("imageOf_t:#{escaped_pid}"))
      return solr_response, document_list
    end

    #use this method instead of get_related_images when being invoked from the helper from a controller
    def get_related_images_from_controller(work_pid)
    escaped_pid=work_pid.gsub(/:/, '\\\\:') # escape the colon found in PIDS for the solr query
    (solr_response, document_list) = get_solr_search_results(escaped_pid)
      return [solr_response, document_list]
    end

    def mint_pid()
      pid_mint_url="http://www.example.com/cgi-bin/drupal_to_repo/mint_pid.cgi?prefix=dil-"
      Net::HTTP.get_response(URI.parse(pid_mint_url)).body.strip
    end
  
    # This method will create a VRA Image object in Fedora.
    # The input is the pid and VRA xml.
    # The output is output indicating a success.
    # If an exception occurs, the controller will catch it.

    def create_vra_image_fedora_object(pid, document)
      
      # create new Fedora object with minted pid
      fedora_object = Multiresimage.new({:pid=>pid})
          
      #set the refid attribute to the new pid
      document.xpath("/vra:vra/vra:image", "vra"=>"http://www.vraweb.org/vracore4.htm").attr("refid", pid)
              
      #set VRA datastream to the xml document
      fedora_object.datastreams["VRA"].content = document.to_s
            
      #save Fedora object
      fedora_object.save()
      
      "<response><returnCode>Save successful</returnCode><pid>" + pid + "</pid></response>"
    end

    # This method will create a VRA Work object in Fedora.
    # The input is the pid and VRA xml.
    # The output is output indicating a success.
    # If an exception occurs, the controller will catch it.
    
    def create_vra_work_fedora_object(pid, document)

      # create new Fedora object with minted pid
      #ActiveFedora.init()
      fedora_object = Vrawork.new({:pid=>pid})
          
      #set the refid attribute to the new pid
      document.xpath("/vra:vra/vra:work", "vra"=>"http://www.vraweb.org/vracore4.htm").attr("refid", pid)
              
      #set VRA datastream to the xml document
      fedora_object.datastreams["VRA"].content = document.to_s
            
      #save Fedora object
      fedora_object.save()
    
      "<response><returnCode>Save successful</returnCode><pid>" + pid + "</pid></response>"
    end
  
    # This method will add a datastream to an object in Fedora.
    # The input is the pid and the datastream's xml, name and label.
    # The output is output indicating a success.
    # If an exception occurs, the controller will catch it.
    
    def update_fedora_object(pid, xml, ds_name, ds_label)
      
      #load Fedora object
      fedora_object = ActiveFedora::Base.find(pid, :cast=>true)
    
      #set datastream to xml from the request
      
      #if datastream doesn't already exist, add_datastream
      #if (fedora_object.datastreams[ds_name].nil?)
        new_ds = ActiveFedora::Datastream.new(:dsID=>ds_name, :dsLabel=>ds_label)
        fedora_object.add_datastream(new_ds)
      #end
      
      #debugger
      fedora_object.datastreams[ds_name].content = xml
    
      #save Fedora object
      #debugger
      fedora_object.save()
    
      #update the solr index
      #debugger
      if (ds_name=="VRA")
        fedora_object.update_index()
      end
      
      returnXml = "<response><returnCode>Update successful</returnCode><pid>" + pid + "</pid></response>"
      
      return returnXml
      
    end

    def add_external_ds(pid, ds_name, ds_label, ds_location, mime_type)
      #load Fedora object
      fedora_object = ActiveFedora::Base.find(pid, :cast=>true)
      #set datastream to xml from the request
      
      #if datastream doesn't already exist, add_datastream
      if (fedora_object.datastreams[ds_name].nil?)
        new_ds = ActiveFedora::Datastream.new(:dsID=>ds_name, :dsLabel=>ds_label, :controlGroup=>"E", :dsLocation=>ds_location, :mimeType=>mime_type)
        fedora_object.add_datastream(new_ds)
      end
    
      #save Fedora object
      fedora_object.save()
      
      "<response><returnCode>Update successful</returnCode><pid>" + pid + "</pid></response>"
    end

  
  end
end