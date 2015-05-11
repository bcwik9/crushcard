class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # run these methods on page load
  before_filter :current_user

  helper_method :current_user

  def current_user
    @current_user ||= unless @current_user 
                        session[:id] ||= request.remote_ip.hash + rand(1000)
                      end
  end

  private

end
