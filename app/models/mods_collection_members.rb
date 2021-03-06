#module Hydra
class ModsCollectionMembers < ActiveFedora::OmDatastream       
  #include Hydra::Datastream::CommonModsIndexMethods

  set_terminology do |t|
    t.root(:path=>"modsCollection", :xmlns=>"http://www.loc.gov/mods/v3", :schema=>"http://www.loc.gov/standards/mods/v3/mods-3-2.xsd")

    # The "owner" is the netID of the user who created the collection
    t.owner( :path => "owner", :index_as => [ :searchable ] )

		t.mods {
			t.title_info(:path=>"titleInfo", :index_as=>[:searchable]) {
			  t.main_title(:path=>"title", :label=>"title", :index_as=>[:searchable])
			}
			t.relatedItem(:index_as=>[:searchable]) {
				t.identifier(:index_as=>[:searchable])
			}
			t.relatedItem(:index_as=>[:searchable]) {
				t.identifier(:index_as=>[:searchable])
			}
			t.type(:index_as=>[:searchable])
			
			t.title(:path=>"titleInfo/title", :index_as=>[:searchable])
		}

  end

    # Generates an empty Mods Collections (used when you call ModsCollectionMembers.new without passing in existing xml)
    def self.xml_template
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.modsCollection(:version=>"3.3", "xmlns:xlink"=>"http://www.w3.org/1999/xlink",
           "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
           "xmlns"=>"http://www.loc.gov/mods/v3",
           "xsi:schemaLocation"=>"http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd") {
        }
      end
      return builder.doc
    end    
 
	# Generates an empty Mods Collections (used when you call ModsCollectionMembers.new without passing in existing xml)
    def self.mods_template item
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.mods {
		   xml.titleInfo {
				xml.title item[:title]
		   }
		   xml.relatedItem {
	           xml.identifier item[:pid]
		   }
		   
	       xml.type item[:type]
		
        }
      end
      return builder.doc
    end    
	
    # Inserts a new MODS record into a modsCollection, representing a collection member
    def insert_member(parms)
	  node = ModsCollectionMembers.mods_template({:title => parms[:member_title], :type => parms[:member_type], :pid => parms[:member_id]}).root()
	  nodeset = self.find_by_terms(:modsCollection)
      unless nodeset.nil?
		self.ng_xml.root.add_child(node)
        self.content = self.ng_xml.to_s
      end
      return node
     end
    
      # Remove the mods entry identified by @index
	  def remove_member_by_index(member_index)
		self.find_by_terms({:mods=>member_index.to_i}).first.remove
		 #self.content = self.ng_xml.to_s
	  end
	  
	# Remove the mods entry identified by pid
	  def remove_member_by_pid(pid)
        #logger.debug("debug xpath: " + self.ng_xml.xpath('//mods:mods/mods:relatedItem/mods:identifier[.="' + pid + '"]', {'mods'=>'http://www.loc.gov/mods/v3'})
        #logger.debug("debug xpath" + self.ng_xml.xpath('//mods:mods/mods:relatedItem/mods:identifier[.="' + pid + '"]', {'mods'=>'http://www.loc.gov/mods/v3'}).to_s)
		#self.ng_xml.xpath('//mods:mods/mods:relatedItem/mods:identifier[.="' + pid + '"]', {'mods'=>'http://www.loc.gov/mods/v3'}).first.remove
		self.ng_xml.xpath('//mods:identifier[.="' + pid + '"]/ancestor::mods:mods', {'mods'=>'http://www.loc.gov/mods/v3'}).first.remove
	    self.content = self.ng_xml.to_s
	  end
	  
	# Moves the mods record to a different index within the datastream
	  def move_member(from_index, to_index)
	    #get node to be moved and clone it
	    moving_node = self.find_by_terms({:mods=>from_index.to_i}).first().clone()
	    #get node at to_index
	    to_node = self.find_by_terms({:mods=>to_index.to_i}).first()
	    #remove the node to be moved at it's original index
	    remove_member_by_index(from_index)
	
	    #if moving node from left to right, add moving node after the to_index node
	    if (from_index < to_index)
	      to_node.after(moving_node)
	    #moving from right to left, add moving node before the to_index node
	    else
	      to_node.before(moving_node)
	      #to_node.add_previous_sibling(moving_node)
	    end
	    
	    self.content = self.ng_xml.to_s
	    
      end
    
      def to_solr(solr_doc=Hash.new)
        solr_doc = super(solr_doc)
        # super is not automatically indexing the new element
        # so we do it explicitly
        owner_hash = Hash[ "owner_tesim" => self.owner ]
        solr_doc = solr_doc.merge( owner_hash )
        # ::Solrizer::Extractor.insert_solr_field_value(solr_doc, "object_type_facet", "Collection")
        #::Solrizer::Extractor.insert_solr_field_value(solr_doc, "title_t", self.find_by_terms("mods/titleInfo/title")) unless self.find_by_terms("mods/titleInfo/title").size == 0
        solr_doc
      end

    end
#end
