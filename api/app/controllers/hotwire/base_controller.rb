# frozen_string_literal: true

module Hotwire
  class BaseController < ApplicationController
    layout 'hotwire'

    before_action :load_retro, only: [:show, :edit, :update, :archive]
    before_action :authenticate_retro!, only: [:show, :edit, :update, :archive]

    private

    def load_retro
      @retro = Retro.friendly.find(params[:retro_slug] || params[:slug] || params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: 'Retro not found'
    end

    def authenticate_retro!
      return unless @retro.is_private?
      return if retro_authenticated?(@retro)

      redirect_to new_retro_session_path(@retro)
    end

    def retro_authenticated?(retro)
      session[:retro_sessions] ||= {}
      session[:retro_sessions][retro.slug].present?
    end

    def mark_retro_authenticated!(retro)
      session[:retro_sessions] ||= {}
      session[:retro_sessions][retro.slug] = true
    end
  end
end
