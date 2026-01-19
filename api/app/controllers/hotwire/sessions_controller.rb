# frozen_string_literal: true

module Hotwire
  class SessionsController < Hotwire::BaseController
    skip_before_action :authenticate_retro!
    before_action :load_retro, except: [:magic_link]

    def new
    end

    def create
      if @retro.validate_login?(params[:password])
        mark_retro_authenticated!(@retro)
        redirect_to retro_path(@retro)
      else
        flash.now[:alert] = 'Incorrect password'
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      session[:retro_sessions]&.delete(@retro.slug)
      redirect_to root_path
    end

    def magic_link
      @retro = Retro.find_by!(join_token: params[:token])
      mark_retro_authenticated!(@retro)
      redirect_to retro_path(@retro)
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: 'Invalid or expired link'
    end
  end
end
