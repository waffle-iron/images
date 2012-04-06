DIL::Application.routes.draw do
  Blacklight.add_routes(self)
  HydraHead.add_routes(self)

  root :to => "catalog#index"

  devise_for :users, :controllers => { :omniauth_callbacks => "users/omniauth_callbacks" }
  
  resources :multiresimages do
    collection do
      get 'aware_tile'
      post 'create_update_fedora_object'
      post 'add_datastream'
      post 'add_external_datastream'
      get 'delete_fedora_object'
      get 'clone_work'
    end
  end
  
  resources :dil_collections
  
  
  match "multiresimages/updatecrop/:id" => "multiresimages#updatecrop"
  match "multiresimages/svg/:id" => "multiresimages#get_svg"
  match "multiresimages/aware_details" => "multiresimages#aware_details"
  match "external_search/search_hydra" => "external_search#index"
  match "dil_collections/add/:id/:member_id" => "dil_collections#add"
  match "dil_collections/remove/:id/:pid" => "dil_collections#remove"
  match "dil_collections/new" => "dil_collections#new"
  match "dil_collections/move/:id/:from_index/:to_index" => "dil_collections#move"

  resources :uploads, :only => [:index] do
    collection do
      post :enqueue
    end
  end
  match "uploads/create" => "uploads#create"
  match "uploads/update_status" => "uploads#update_status"
  
end
