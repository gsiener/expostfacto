# frozen_string_literal: true

class Hotwire::RetrosController < Hotwire::BaseController
  skip_before_action :load_retro, only: [:index, :new, :create]
  skip_before_action :authenticate_retro!, only: [:index, :new, :create]

  def index
    @retros = current_user&.retros || []
  end

  def show
    @items_by_category = {
      happy: @retro.items.where(category: 'happy', done: false).order(:created_at),
      meh: @retro.items.where(category: 'meh', done: false).order(:created_at),
      sad: @retro.items.where(category: 'sad', done: false).order(:created_at)
    }
    @action_items = @retro.action_items.where(archived: false).order(:created_at)
    @highlighted_item = @retro.highlighted_item
  end

  def new
    @retro = Retro.new
  end

  def create
    @retro = Retro.new(retro_params)
    if @retro.save
      mark_retro_authenticated!(@retro)
      redirect_to retro_path(@retro), notice: 'Retro created!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @retro.update(retro_params)
      # Broadcast to all connected clients via ActionCable
      RetrosChannel.broadcast(@retro.reload)
      redirect_to retro_path(@retro), notice: 'Settings saved!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    RetroArchiveService.archive(@retro, Time.current, false)
    # Broadcast to all connected clients via ActionCable
    RetrosChannel.broadcast(@retro.reload)
    redirect_to retro_path(@retro), notice: 'Archived!'
  end

  private

  def retro_params
    params.require(:retro).permit(:name, :slug, :password, :video_link, :is_private)
  end

  def current_user
    # For now, no user authentication required
    nil
  end
end
