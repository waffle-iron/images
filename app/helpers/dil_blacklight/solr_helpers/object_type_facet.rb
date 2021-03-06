module DIL_Blacklight::SolrHelpers::ObjectTypeFacet

  def multiresimage_object_type_facet(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []

        # Only apply this if the search is happening from inside the Hydra app.
        # External searches need Works and Images (Hydra app just needs Images).
    if (self.class.name != "ExternalSearchController")
      solr_parameters[:fq] << 'object_type_facet:(Multiresimage)'
    end
  end

end
