# frozen_string_literal: true

module Hotwire
  class ItemsController < Hotwire::BaseController
    before_action :load_retro
    before_action :authenticate_retro!, except: [:create, :vote]
    before_action :load_item, only: [:update, :destroy, :vote, :highlight, :unhighlight, :done]

    def create
      @item = @retro.items.build(item_params)
      if @item.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to retro_path(@retro) }
        end
      else
        head :unprocessable_content
      end
    end

    def update
      if @item.update(item_params)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to retro_path(@retro) }
        end
      else
        head :unprocessable_content
      end
    end

    def destroy
      @item.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to retro_path(@retro) }
      end
    end

    def vote
      @item.increment!(:vote_count)
      TelemetryMetricsCollector.record_vote(@item)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to retro_path(@retro) }
      end
    end

    def highlight
      @retro.update!(highlighted_item_id: @item.id)
      # Item update broadcast handled by model callback
      @item.touch # Trigger update to broadcast changes
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to retro_path(@retro) }
      end
    end

    def unhighlight
      @item.update!(done: true)
      @retro.update!(highlighted_item_id: nil)
      # Item update broadcast handled by model callback
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to retro_path(@retro) }
      end
    end

    def done
      @item.update!(done: !@item.done)
      was_highlighted = @retro.highlighted_item_id == @item.id
      @retro.update!(highlighted_item_id: nil) if @item.done && was_highlighted
      # Item update broadcast handled by model callback
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to retro_path(@retro) }
      end
    end

    private

    def load_item
      @item = @retro.items.find(params[:id])
    end

    def item_params
      params.require(:item).permit(:description, :category)
    end
  end
end
