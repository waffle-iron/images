class CreateInstitutionalCollectionDisplays < ActiveRecord::Migration
  def change
    create_table :institutional_collection_displays do |t|
      t.text :identity_image_filename
      t.text :pid
    end
  end
end
