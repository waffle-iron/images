require 'spec_helper'

describe MultiresimagesController do
  describe "destroy" do
    before do
      @img = Multiresimage.create
      @user = FactoryGirl.find_or_create(:archivist)
      sign_in @user
    end
    describe "an image that I have edit permissions on" do
      before do
        @img.apply_depositor_metadata(@user.email)
        @img.save
      end
      it "should be destroyed" do
        delete :destroy, :id=>@img.pid
        Multiresimage.exists?(@img.pid).should be_false
        flash[:notice].should == "Image has been deleted"
        response.should redirect_to(catalog_index_path)
      end
      it "should be removed from the session too"do
        session[:files] = [@img.pid]
        delete :destroy, :id=>@img.pid
        session[:files].should == []
      end
    end
    describe "an image that I don't have edit permissions on" do
      it "should not be destroyed" do
        delete :destroy, :id=>@img.pid
        Multiresimage.exists?(@img.pid).should be_true
      end
    end
  end

  describe "edit and image" do
    before do
      @img = Multiresimage.create
      @user = FactoryGirl.find_or_create(:archivist)
      sign_in @user
    end
    describe "that I have edit permissions on" do
      before do
        @img.apply_depositor_metadata(@user.email)
        @img.save
      end
      it "should be success" do
        get :edit, :id=>@img.pid
        assigns[:multiresimage].should == @img
        response.should be_success
      end
    end
    describe "that I don't have edit permissions on" do
      it "should redirect to catalog" do
        get :edit, :id=>@img.pid
        response.should redirect_to(root_path)
        flash[:alert].should == 'You are not authorized to access this page.'
      end
    end
  end
end
