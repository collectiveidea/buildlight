class PagesController < ApplicationController
  def letsencrypt
    render text: ENV["LETS_ENCRYPT_CHALLENGE"]
  end
end
