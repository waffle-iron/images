require 'rails_helper'

describe Multiresimage do

  # This isn't a valid test. We don't instantiate these objects with file names
  # describe "a new instance with a file name" do
  #   m = Multiresimage.new(:file_name=>'readme.txt')
  #   expect(m.file_name).to eq('readme.txt')
  # end

  pending("It doesn't look like we're using policies") do
    describe "should have an admin policy" do
      before do
        @policy = AdminPolicy.create
      end
      after do
        @policy.delete
      end
      subject { Multiresimage.new(:admin_policy=>@policy) }
      its(:admin_policy) { should == @policy }

    end
  end

  describe "#vra_save" do
    before( :each ) do
      @xml_from_menu = File.read( "#{ Rails.root }/spec/fixtures/vra_image_sample.xml" )
      @m = Multiresimage.create( from_menu: true, vra_xml: @xml_from_menu )
    end

    it 'creates the appropriate vra:image XML' do
      xml_from_rir  = File.read( "#{ Rails.root }/spec/fixtures/vra_image_sample_complete.xml" )
      doc1 = Nokogiri::XML(@m.datastreams['VRA'].to_xml)
      doc2 = Nokogiri::XML(xml_from_rir)
      expect(doc1).to be_equivalent_to(doc2).ignoring_content_of(["vra|locationSet"]).ignoring_attr_values( 'relids', 'refid', 'id' )
    end

    it "ensures object type facet is correct" do
      expect( @m.VRA.to_solr["object_type_facet"] ).to eq ["Multiresimage"]
    end
  end

  context "create datastreams" do

    before( :each ) do
      @m = Multiresimage.create
      @sample_tiff = "#{ Rails.root }/spec/fixtures/images/internet.tiff"
      @sample_jp2  = "#{ Rails.root }/spec/fixtures/images/internet.jp2"
    end

    describe "#create_archv_img_datastream" do
      it "populates the ARCHV-IMG datastream" do
        @m.create_archv_img_datastream( "http://upload.wikimedia.org/wikipedia/commons/0/0e/Haeberli_off_luv24.tif" )
        @m.save!
        expect( @m.datastreams[ "ARCHV-IMG" ].content ).to_not be_nil
      end
    end

    describe "#create_archv_techmd_datastream" do
      it "populates the ARCHV-TECHMD datastream" do
        jhove_xml = Nokogiri::XML.parse( File.read( "#{Rails.root}/spec/fixtures/archv_jhove_output.xml" ))
        @m.create_archv_techmd_datastream( @sample_tiff )
        expect( @m.datastreams["ARCHV-TECHMD"].content ).to be_equivalent_to( jhove_xml ).ignoring_content_of( "date" )
      end
    end

    describe "#create_archv_exif_datastream" do
      it "populates the ARCHV-EXIF datastream" do
        exif_xml = `#{ Rails.root }/lib/exif.pl #{ @sample_tiff }`
        sleep 1
        @m.create_archv_exif_datastream( @sample_tiff )
        expect( @m.datastreams[ "ARCHV-EXIF" ].content ).to match_xml_except( exif_xml, 'File_Access_Date_Time', 'File Access Date/Time' )
      end
    end

    describe "#create_deliv_techmd_datastream" do
      it "populates the DELIV-TECHMD datastream" do
        jhove_xml = File.open("#{ Rails.root }/spec/fixtures/deliv_jhove_output.xml").read
        @m.create_deliv_techmd_datastream( @sample_jp2 )
        expect( @m.datastreams[ "DELIV-TECHMD" ].content ).to match_xml_except( jhove_xml, 'date' )
      end
    end

    describe "#create_deliv_ops_datastream" do
      it "populates the DELIV-OPS datastream" do
        deliv_ops_xml = <<-EOF
<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\">
  <svg:image x=\"0\" y=\"0\" height=\"664\" width=\"600\" xlink:href=\"/inu-dil/hydra/test/from-menu/#{ @m.pid.gsub( /:/, '-' )}.jp2\"/>
</svg:svg>
EOF
        @m.create_deliv_techmd_datastream( @sample_jp2 )
        @m.create_deliv_ops_datastream
        expect( @m.datastreams[ "DELIV-OPS" ].content).to eq( deliv_ops_xml.chomp )
      end
    end

    describe "#create_deliv_img_datastream" do
      it "populates the DELIV-IMG datastream" do
        public_jp2 = "http://memory.loc.gov/service/gmd/gmd4/g4974/g4974s/ct001338.jp2"
        @m.create_deliv_img_datastream( public_jp2 )
        @m.save!
        expect( @m.datastreams[ "DELIV-IMG" ].content ).to_not be_nil
      end
    end
  end

  # We don't have working/updated factories right now
  pending "should belong to multiple collections" do
    before do
      @collection1 = FactoryGirl.create(:collection)
      @collection2 = FactoryGirl.create(:collection)
      @collection3 = FactoryGirl.create(:collection)
    end
    subject { Multiresimage.new(:collections=>[@collection1, @collection2]) }
    its(:collections) { should == [@collection1, @collection2] }
  end


  context "with an associated work" do
    xml = File.read("#{Rails.root}/spec/fixtures/vra_minimal.xml")
    doc = Nokogiri::XML( xml )
    doc.xpath( "//vra:earliestDate" )[ 0 ].content = '0000'
    xml = doc.to_s

    # this will create a vrawork and associate them with each other
    img = Multiresimage.create(vra_xml: xml, from_menu: true, pid: "my:pid")
    img.save

    it "should have related_ids" do
      expect( img.related_ids ).to eq img.vraworks.first.pid
    end
  end


  context "to_solr" do
    before do
      @img = Multiresimage.new
      @img.titleSet_display = 'Evanston Public Library. Exterior: facade'
    end
    subject { @img.to_solr }
    it "should have title_display" do
      expect(subject['title_display']).to eq "Evanston Public Library. Exterior: facade"
    end
  end

  context "with rightsMetadata" do
    subject do
      m = Multiresimage.new()
      m.rightsMetadata.update_permissions("person"=>{"person1"=>"read","person2"=>"discover"}, "group"=>{'group-6' => 'read', "group-7"=>'read', 'group-8'=>'edit'})
      m.save
      m
    end
    it "should have read groups accessor" do
      expect( subject.read_groups ).to eq ['group-6', 'group-7']
    end
    it "should have read groups writer" do
      subject.read_groups = ['group-2', 'group-3']
      expect( subject.rightsMetadata.groups ).to eq( {'group-2' => 'read', 'group-3'=>'read', 'group-8' => 'edit'} )
      expect( subject.rightsMetadata.individuals ).to eq( {"person1"=>"read","person2"=>"discover"} )
    end
    it "should only revoke eligible groups" do
      subject.set_read_groups(['group-2', 'group-3'], ['group-6'])
      # 'group-7' is not eligible to be revoked
      expect( subject.rightsMetadata.groups ).to eq( {'group-2' => 'read', 'group-3'=>'read', 'group-7' => 'read', 'group-8' => 'edit'} )
      expect( subject.rightsMetadata.individuals ).to eq( {"person1"=>"read","person2"=>"discover"} )
    end
  end

  describe "update with an attached vrawork" do
    before do
      @img = Multiresimage.create
      @work = Vrawork.create
      @img.vraworks = [@work]
    end
    it "should update the work" do
      @img.update_attributes(:titleSet_display => "Woah cowboy")
      expect( @img.vraworks.first.titleSet_display_work ).to eq "Woah cowboy"

    end
  end

  describe "with related works" do
    before do
      @img = Multiresimage.new
      @work1 = Vrawork.create
      @work2 = Vrawork.create
      @work3 = Vrawork.create
      vra_xml = <<-eos
      <vra:vra xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:marc="http://www.loc.gov/MARC21/slim" xmlns:mods="http://www.loc.gov/mods/v3" xmlns:vra="http://www.vraweb.org/vracore4.htm" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vraweb.org/vracore4.htm http://www.vraweb.org/projects/vracore4/vra-4.0-restricted.xsd">
        <vra:image id="inu-dil-77334_w" refid="inu:dil-d42f25cc-deb2-4fdc-b41b-616291578c26">

          <vra:relationSet>
            <vra:display>Evanston Public Library. Exterior: facade</vra:display>
            <vra:relation pref="true" relids="#{@work1.pid}" type="imageOf">Evanston Public Library. Exterior: facade</vra:relation>
            <vra:relation relids="#{@work2.pid}" type="imageOf">Evanston Public Library. Exterior: facade</vra:relation>
            <vra:relation relids="#{@work3.pid}" type="imageOf">Evanston Public Library. Exterior: facade</vra:relation>
          </vra:relationSet>
        </vra:image>
      </vra:vra>
      eos
      @img.datastreams["VRA"] = VRADatastream.from_xml(vra_xml)
    end
    it "preferred_related_work should return the preferred work" do
      expect( @img.preferred_related_work ).to eq @work1
    end
    it "other_related_works should be the others" do
      expect( @img.other_related_works ).to eq( [@work2, @work3] )
    end
  end
end

