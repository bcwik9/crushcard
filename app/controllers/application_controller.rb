class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  around_filter :set_locale
  before_filter :current_user


=begin
  before_filter :require_ssl!
  def require_ssl!
    update_protocol = request.protocol != "https://"
    return unless update_protocol
    to_path = File.join("https://#{request.domain}", request.original_fullpath)
    puts "REDIRECT TO SSL: #{to_path}".red
    redirect_to to_path, status: 301
  end
=end

  private
 
  # Finds the User with the ID stored in the session with the key
  # :current_user_id This is a common way to handle user login in
  # a Rails application; logging in sets the session value and
  # logging out removes it.
  def current_user
    session[:id] ||= request.remote_ip.hash + rand(1000)
    @_current_user = session[:id]
  end

  def set_locale
    locale = if lp = params[:locale]
               lp.include?('crush') ? :en : :en_tish
             else
               request.domain.include?('tishnow') ? :en_tish : :en
             end
    I18n.with_locale(locale) do
      yield
    end
  end
end
