require 'dil/pid_minter'
require 'pry'

class DilCollectionsController < ApplicationController

  include Blacklight::Catalog
  include Blacklight::SolrHelper
  include DIL::PidMinter

  after_action :delete_powerpoint, only: [:update, :add, :remove, :move]

  def new_public_collection

  end

  def create_public_collection
    #authorize!(:create, DILCollection)

    new_collection = DILCollection.new(:pid => mint_pid("dil"))
    coll = InstitutionalCollection.new( pid: new_collection.pid )
    #"Melville J. Herskovits Library of African Studies"
    #coll.title = "#{params[:title]}|#{params[:facets]}"
    coll.title = "#{params[:unit_name]} | #{params[:collection_name]}"
    simple_col_obj = InstitutionalCollection::InstitutionalCollectionDisplay.new
    simple_col_obj.identity_image_filename = "#{params[:identity_image_filename]}"
    simple_col_obj.pid = new_collection.pid

    simple_col_obj.save

    coll.rightsMetadata
    coll.default_permissions
    coll.default_permissions = [{:type=>"group", :access=>"read", :name=>"public"}]
    coll.save

    collection_identity_img = Multiresimage.find( Multiresimage.last.pid )
    #collection_identity_img = Multiresimage.find( "#{params[:collection_identity_img_pid]}" )

    #how to add batch of images to a new collection?
    collection_identity_img.add_relationship( :is_governed_by, coll )
    collection_identity_img.save

    redirect_to :back, notice: "Public Collection #{coll.title} was successfully created."
  end

  def make_institutional_collection_public
    #authorize!(:update, DILCollection)
    img = Multresimage.find(params[:pid])
    #need to get old collection obj
    img.remove_relationship( :is_governed_by, old_coll )

    #new_collection.pid -> either get or create
    #make sure that all images that use this are correctly reflecting new state of collection
    coll = InstitutionalCollection.new( pid: new_collection.pid )

    img.add_relationship( :is_governed_by, new_coll )
  end

  def create
    authorize!(:create, DILCollection)
	  #make sure collection's name isn't a reserved name for Details collections
	  if params[:dil_collection][:title].downcase == DIL_CONFIG['dil_details_collection'].downcase
	    flash[:alert] = "Cannot use that collection name. That name is reserved."
	  else
	    edit_users_array = DIL_CONFIG['admin_staff'] | Array.new([current_user.user_key])
	    @dil_collection = DILCollection.new(:pid=>mint_pid("dil-local"))
  		@dil_collection.apply_depositor_metadata(current_user.user_key)
  	  @dil_collection.edit_users = edit_users_array
  		# This allows ALL Collections created by users to be available for anyone with the link
  		@dil_collection.read_groups = ["registered"]
  		#@dil_collection.set_collection_type('dil_collection')
  		@dil_collection.descMetadata.title = params[:dil_collection][:title]
      @dil_collection.owner = current_user.uid
  		@dil_collection.save!
	  end
	  redirect_to :back
  end

  def update
    @collection = DILCollection.find(params[:id])
    authorize! :update, @collection
    read_groups = params[:dil_collection].delete(:read_groups)
    if read_groups.present?
      eligible = current_user.owned_groups.map(&:code)
      @collection.set_read_groups(read_groups, current_user.owned_groups.map(&:code))
    end
    if params[:dil_collection][:title].downcase == DIL_CONFIG['dil_details_collection'].downcase
      flash[:alert] = "Cannot use that collection name. That name is reserved."
    else
      @collection.update_attributes(params[:dil_collection])
      if @collection.save
        flash[:notice] = "Saved changes to #{@collection.title}"
      else
        flash[:alert] = "Failed to save your changes!"
      end
    end
    redirect_to dil_collection_path(@collection)
  end

  # This method is for adding an image or collection to an existing collection
  # It was originally for adding one item at a time, with that item's id in the params.
  # It can now add multiple items in one call. The hydra-batch-edit gem already had a way to
  # select multiple items from a search result.  It stores the list of selected items in the session.
  # This code now checks to see if there are multiple items in the list.  If so, it will make a call to
  # collection.insert_member for each one.
  def add
     begin
      LockedObject.obtain_lock(params[:id], "collection - add object", current_user.id)
      collection = DILCollection.find(params[:id])
      # Does user have edit access on the collection?
      authorize! :edit, collection
       # Check to see if there is a batch_select_ids session variable that has values.
      # If so, iterate through and add those items to the collection
      if session[:batch_select_ids].present?

        #assign to variable in this scope so the session can be cleared right away
        #for the page refresh
        pid_list = session[:batch_select_ids]

        #Clear the session variable
        session.delete(:batch_select_ids)

        # Make sure the selected image is in the list (user might not have checked it)
        if !pid_list.include? (params[:member_id])
          pid_list << params[:member_id]
        end

        pid_list.each do |pid|
          begin
            LockedObject.obtain_lock(pid, "image - add to collection", current_user.id)
            fedora_object = ActiveFedora::Base.find(pid, :cast=>true)

            # Does user have read access on the item?
            authorize! :show, fedora_object

            # Add to collection
            collection.insert_member(fedora_object)
          ensure
            LockedObject.release_lock(pid)
          end
        end
      else
        begin
          LockedObject.obtain_lock(params[:member_id], "image - add to collection", current_user.id)
          fedora_object = ActiveFedora::Base.find(params[:member_id], :cast=>true)

          # Does user have read access on the item?
          authorize! :show, fedora_object
          collection.insert_member(fedora_object)
        ensure
          LockedObject.release_lock(params[:member_id])
        end
      end
      ensure
        LockedObject.release_lock(params[:id])
      end
    render :nothing => true
  end

  #remove an image or subcollection from the collection
  def remove
    begin
      #member_index = params[:member_index];
      LockedObject.obtain_lock(params[:id], "collection - remove object", current_user.id)
      collection = DILCollection.find(params[:id])
      authorize! :update, collection
      LockedObject.obtain_lock(params[:pid], "image - remove from collection", current_user.id)
      collection.remove_member_by_pid(params[:pid])
     ensure
       LockedObject.release_lock(params[:id])
       LockedObject.release_lock(params[:pid])
     end
      redirect_to dil_collection_path(collection)
  end

  #delete the collection
  def destroy
    begin
      LockedObject.obtain_lock(params[:id], "collection - deleting collection", current_user.id)
      collection = DILCollection.find(params[:id])
      authorize! :destroy, collection

    #remove all members from collection's mods and rels-ext, and update members rels-ext, too
      #collection.members.find_by_terms(:mods, :relatedItem, :identifier).each do |member_pid|
       # collection.remove_member_by_pid(member_pid)
      #end

      ##remove collection from parent collections' mods and rels-ext and it's own rels-ext and mods
      #collection.parent_collections.each do |parent_collection|
        #parent_collection.remove_member_by_pid(collection.pid)
     # end

      #remove all images from collection
      collection.multiresimages.each do |image|
        begin
          LockedObject.obtain_lock(image.pid, "collection - remove image", current_user.id)
          collection.remove_member_by_pid(image.pid)
        ensure
          LockedObject.release_lock(image.pid)
        end
      end

      #remove all subcollections from collection
      collection.subcollections.each do |subcollection|
        begin
          LockedObject.obtain_lock(subcollection.pid, "collection - remove subcollection", current_user.id)
          collection.remove_member_by_pid(subcollection.pid)
        ensure
          LockedObject.release_lock(subcollection.pid)
        end
      end

      #remove collection from parent collections
      collection.parent_collections.each do |parent_collection|
        begin
          LockedObject.obtain_lock(parent_collection.pid, "collection - remove parent collection", current_user.id)
          parent_collection.remove_member_by_pid(collection.pid)
        ensure
          LockedObject.release_lock(parent_collection.pid)
        end
      end

      #delete the DILCollection object
      collection.delete
      flash[:notice] = "Image Group deleted"

    rescue Exception => e
      flash[:error] = "Error deleting Image Group"
      logger.debug("ERROR ERROR #{e.to_s}")

    ensure
      LockedObject.release_lock(params[:id])
      redirect_to catalog_index_path
    end

  end

  #move a member item in a collection from original position to new position
  def move
    begin
      LockedObject.obtain_lock(params[:id], "collection - reorder images", current_user.id)
      collection = DILCollection.find(params[:id])
      authorize! :update, collection
	  ds = collection.datastreams["members"]

      #call the move_member method within mods_collection_members
      ds.move_member(params[:from_index], params[:to_index])
      collection.save!
    ensure
      LockedObject.release_lock(params[:id])
    end
	render :nothing => true
  end

  def show
    @collection = DILCollection.find(params[:id])
    authorize! :show, @collection

    respond_to do |format|
      format.pptx {
        if @collection.powerpoint.content.present?
          send_data @collection.powerpoint.content, type: "pptx", filename: "#{@collection.title}.pptx"
        else
          redirect_to dil_collection_path(@collection), alert: "PowerPoint file doesn't exist"
        end
      }
      format.html
    end
  end

  def generate_powerpoint
    @collection = DILCollection.find(params[:id])
    authorize! :update, @collection

    Delayed::Job.enqueue GeneratePowerpointJob.new(@collection.pid)
  end

  def download_powerpoint
    @collection = DILCollection.find(params[:id])
    authorize! :show, @collection

    respond_to do |format|
      format.pptx { send_data @collection.powerpoint.content, type: "pptx", filename: "#{@collection.title}.pptx"}
    end
  end

  def powerpoint_check
    @collection = DILCollection.find(params[:id])
    authorize! :show, @collection

    if @collection.powerpoint.content.present?
      render text: true
    else
      render text: false
    end
  end

  # This will return a JSON string for all the subcollections of the collection
  def get_subcollections
    begin
      collection = DILCollection.find(params[:id])
      authorize! :show, collection

      # Get the subcollection JSON as a string and convert to a hash
      return_json = JSON.parse( collection.get_subcollections_json )
      # For each subcollection ...
      return_json.each do |subcoll|
        # Create a DILCollection object
        coll = DILCollection.find( subcoll[ "pid" ] )
        # Check to see if the current_user is an admin
        if current_user.admin?
          # If so, add the owner to the JSON
          # If the owner is empty, the JSON will contain "null"
          subcoll[ "owner" ] = coll.owner
        end
      end
      logger.debug( "return_json: #{ return_json }" )
      # Return the JSON as a string
      return_json.to_json

    rescue Exception => e
      #error
      return_json = "{\"status\":exception}"
      logger.debug("get_subcollections exception: #{e.to_s}")

    ensure #this will get called even if an exception was raised
      respond_to do |format|
        #This wasn't working quite right, so just storing JSON in a variable instead of using .to_json
        #format.json { render :layout =>  false, :json => collection.to_json(:methods=>:get_subcollections) }
        format.json { render :layout =>  false, :json => return_json}
      end

    end
  end

  #TODO: Move code to lib directory as this is an API
  # API to return a user's collections' titles and pids as JSON
  def get_collections
    begin
      return_json = ""
      collection_json = current_user.collections.to_json
      #if user logged in
      if current_user.present? and collection_json.present?
        # get the array of Solr results for the user's collections
        return_json = collection_json
      else
        return_json = "{\"status\":exception}"
      end
    rescue Exception => e
      #error
      return_json = "{\"status\":exception}"
      logger.error("get_collections exception: #{e.to_s}")

    ensure #this will get called even if an exception was raised
      respond_to do |format|
        #This wasn't working quite right, so just storing JSON in a variable instead of using .to_json
        #format.json { render :layout =>  false, :json => collection.to_json(:methods=>:get_subcollections) }
        format.json { render :layout =>  false, :json => return_json}
      end
    end
  end

  # This API is called when a user selects one image using the checkbox to add it to the batch selection list.
  # The list is stored in the session as :batch_select_ids
  # JSON is returned
  def add_to_batch_select
    begin

     # If session variable exists and doesn't include the id already, add it to the array
     if session[:batch_select_ids].present? and !session[:batch_select_ids].include? (params[:id])
       session[:batch_select_ids] << params[:id]
       return_json = "{\"status\":\"success\", \"size\":\"#{session[:batch_select_ids].size}\"}"
     elsif !session[:batch_select_ids].present?
     # Create the session variable and add the pid
       (session[:batch_select_ids] ||= []) << params[:id]
       return_json = "{\"status\":\"success\", \"size\":\"1\"}"
     else
       return_json = "{\"status\":\"success,dup\"}"
     end

    rescue Exception => e
      #error
       return_json = "{\"status\":\"exception\"}"

    ensure #this will get called even if an exception was raised
      respond_to do |format|
       format.json { render :layout =>  false, :json => return_json}
      end

    end
  end

  # This API is called when a user de-selects one image using the checkbox to remove it from the batch selection list.
  # The list is stored in the session as :batch_select_ids
  # JSON is returned
  def remove_from_batch_select
    begin
      if session[:batch_select_ids].present?
        session[:batch_select_ids].delete(params[:id])
        return_json = "{\"status\":\"success\", \"size\":\"#{session[:batch_select_ids].size}\"}"
      else
        return_json = "{\"status\":\"was_empty\"}"
      end
    rescue Exception => e
       #error
       return_json = "{\"status\":\"exception\"}"
    ensure #this will get called even if an exception was raised
      respond_to do |format|
       format.json { render :layout =>  false, :json => return_json}
      end

    end
  end

  # This will remove "registered" from read_groups
  # A link exists on show.html.erb
  def make_private
    c = DILCollection.find(params[:id])
    if c.read_groups.include? "registered"
      temp = c.read_groups - ['registered']
      c.read_groups = [temp]
      c.save!
    end
    redirect_to dil_collection_path(c)
  end

  # This will add "registered" to read_groups
  # A link exists on show.html.erb
  def make_public
    c = DILCollection.find(params[:id])
    if !c.read_groups.include? "registered"
      temp = c.read_groups + ['registered']
      c.read_groups = [temp]
      c.save!
    end
    redirect_to dil_collection_path(c)
  end

  # Catalog searching in dil_collections
  def search_action_url
    url_for(controller: '/catalog', action: 'index', only_path: true)
  end

  private

  def delete_powerpoint
    @collection = DILCollection.find(params[:id])
    @collection.powerpoint.delete if @collection.powerpoint.content.present?
  end

end
