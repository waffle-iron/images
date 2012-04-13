class DILCollection < ActiveFedora::Base
  
  include Hydra::ModelMethods
  include Dil::RightsMetadata
  
  # Uses the Hydra Rights Metadata Schema for tracking access permissions & copyright
  has_metadata :name => "rightsMetadata", :type => Hydra::Datastream::RightsMetadata 
  
  # Uses the Hydra MODS Article profile for tracking most of the descriptive metadata
  has_metadata :name => "descMetadata", :type => Hydra::ModsCollection 

  # Uses the Hydra modsCollection profile for collection list
  has_metadata :name => "members", :type => Hydra::ModsCollectionMembers 


  delegate :title, :to=>'descMetadata', :unique=>true

  validates :title, :presence => true

  def insert_member(image)
    image.collections << self
    image.save!
    members.insert_member(:member_id=>image.pid, :member_title=>image.titleSet_display)
  end
  
end
