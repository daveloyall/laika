class ContentErrorsController < ApplicationController

  def mark
    if request.xhr?
      @error = ContentError.find(params[:id])
      @error.update_attributes!(:state => params[:content_error][:state])
      render :text => '1'
    end
  end

end
