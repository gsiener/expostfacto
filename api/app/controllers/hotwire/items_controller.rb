# frozen_string_literal: true

class Hotwire::ItemsController < Hotwire::BaseController
  before_action :load_retro
  before_action :authenticate_retro!, except: [:create, :vote]
  before_action :load_item, only: [:update, :destroy, :vote, :highlight, :unhighlight, :done]

  def create
    @item = @retro.items.build(item_params)
    if @item.save
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
    if @item.update(item_params)
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
    @item.destroy
    # Broadcast to all connected clients via ActionCable
    RetrosChannel.broadcast(@retro.reload)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to retro_path(@retro) }
    end
  end

  def vote
    @item.increment!(:vote_count)
    # Broadcast to all connected clients via ActionCable
    RetrosChannel.broadcast(@retro.reload)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to retro_path(@retro) }
    end
  end

  def highlight
    @retro.update!(highlighted_item_id: @item.id)
    # Broadcast to all connected clients via ActionCable
    RetrosChannel.broadcast(@retro.reload)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to retro_path(@retro) }
    end
  end

  def unhighlight
    @item.update!(done: true)
    @retro.update!(highlighted_item_id: nil)
    # Broadcast to all connected clients via ActionCable
    RetrosChannel.broadcast(@retro.reload)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to retro_path(@retro) }
    end
  end

  def done
    @item.update!(done: !@item.done)
    # Clear highlight if marking as done
    @retro.update!(highlighted_item_id: nil) if @item.done && @retro.highlighted_item_id == @item.id
    # Broadcast to all connected clients via ActionCable
    RetrosChannel.broadcast(@retro.reload)

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
