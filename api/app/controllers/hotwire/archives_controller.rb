# frozen_string_literal: true

module Hotwire
  class ArchivesController < Hotwire::BaseController
    before_action :load_retro
    before_action :authenticate_retro!

    def index
      @archives = @retro.archives.order(created_at: :desc)
    end

    def show
      @archive = @retro.archives.find(params[:id])
      @items = @archive.items
      @action_items = @archive.action_items
    end
  end
end
