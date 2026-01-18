# frozen_string_literal: true

class Hotwire::ActionItemsController < Hotwire::BaseController
  before_action :load_retro
  before_action :load_action_item, only: [:update, :destroy, :toggle_done]
  skip_before_action :authenticate_retro!

  def create
    @action_item = @retro.action_items.build(action_item_params)
    if @action_item.save
      # Broadcast to all connected clients via ActionCable
      RetrosChannel.broadcast(@retro.reload)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to retro_path(@retro) }
      end
    else
      head :unprocessable_entity
    end
  end

  def update
    if @action_item.update(action_item_params)
      # Broadcast to all connected clients via ActionCable
      RetrosChannel.broadcast(@retro.reload)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to retro_path(@retro) }
      end
    else
      head :unprocessable_entity
    end
  end

  def destroy
    @action_item.destroy
    # Broadcast to all connected clients via ActionCable
    RetrosChannel.broadcast(@retro.reload)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to retro_path(@retro) }
    end
  end

  def toggle_done
    @action_item.update!(done: !@action_item.done?)
    # Broadcast to all connected clients via ActionCable
    RetrosChannel.broadcast(@retro.reload)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to retro_path(@retro) }
    end
  end

  private

  def load_action_item
    @action_item = @retro.action_items.find(params[:id])
  end

  def action_item_params
    params.require(:action_item).permit(:description)
  end
end
