# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hotwire::ItemsController', type: :request do
  let!(:retro) { Retro.create!(name: 'Test Retro', slug: 'test-retro') }

  describe 'POST /retros/:retro_slug/items' do
    let(:valid_params) do
      {
        item: {
          description: 'Great sprint!',
          category: 'happy'
        }
      }
    end

    context 'HTML request' do
      it 'creates a new item' do
        expect do
          post retro_items_path(retro), params: valid_params
        end.to change(Item, :count).by(1)
      end

      it 'redirects to retro show page' do
        post retro_items_path(retro), params: valid_params

        expect(response).to redirect_to(retro_path(retro))
      end

      it 'creates the item with correct attributes' do
        post retro_items_path(retro), params: valid_params

        item = Item.last
        expect(item.description).to eq('Great sprint!')
        expect(item.category).to eq('happy')
        expect(item.retro).to eq(retro)
      end
    end

    context 'Turbo Stream request' do
      it 'creates a new item' do
        expect do
          post retro_items_path(retro),
               params: valid_params,
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        end.to change(Item, :count).by(1)
      end

      it 'returns turbo stream response' do
        post retro_items_path(retro),
             params: valid_params,
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'includes turbo stream prepend action' do
        post retro_items_path(retro),
             params: valid_params,
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('happy-items')
      end
    end

    context 'with meh category' do
      let(:meh_params) do
        {
          item: {
            description: 'Need to improve',
            category: 'meh'
          }
        }
      end

      it 'creates item in meh category' do
        post retro_items_path(retro),
             params: meh_params,
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(Item.last.category).to eq('meh')
        expect(response.body).to include('meh-items')
      end
    end

    context 'with sad category' do
      let(:sad_params) do
        {
          item: {
            description: 'This was difficult',
            category: 'sad'
          }
        }
      end

      it 'creates item in sad category' do
        post retro_items_path(retro),
             params: sad_params,
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(Item.last.category).to eq('sad')
        expect(response.body).to include('sad-items')
      end
    end

    context 'with empty description' do
      let(:invalid_params) do
        {
          item: {
            description: '',
            category: 'happy'
          }
        }
      end

      it 'does not create an item and returns unprocessable entity' do
        expect do
          post retro_items_path(retro), params: invalid_params
        end.not_to change(Item, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'PATCH /retros/:retro_slug/items/:id' do
    let!(:item) { retro.items.create!(description: 'Original description', category: 'happy') }

    context 'HTML request' do
      it 'updates the item' do
        patch retro_item_path(retro, item), params: { item: { description: 'Updated description' } }

        expect(item.reload.description).to eq('Updated description')
      end

      it 'redirects to retro show page' do
        patch retro_item_path(retro, item), params: { item: { description: 'Updated' } }

        expect(response).to redirect_to(retro_path(retro))
      end
    end

    context 'Turbo Stream request' do
      it 'returns turbo stream response' do
        patch retro_item_path(retro, item),
              params: { item: { description: 'Updated' } },
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe 'DELETE /retros/:retro_slug/items/:id' do
    let!(:item) { retro.items.create!(description: 'To be deleted', category: 'happy') }

    context 'HTML request' do
      it 'deletes the item' do
        expect do
          delete retro_item_path(retro, item)
        end.to change(Item, :count).by(-1)
      end

      it 'redirects to retro show page' do
        delete retro_item_path(retro, item)

        expect(response).to redirect_to(retro_path(retro))
      end
    end

    context 'Turbo Stream request' do
      it 'deletes the item and returns turbo stream' do
        expect do
          delete retro_item_path(retro, item),
                 headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        end.to change(Item, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe 'POST /retros/:retro_slug/items/:id/vote' do
    let!(:item) { retro.items.create!(description: 'Voteable item', category: 'happy', vote_count: 0) }

    context 'HTML request' do
      it 'increments the vote count' do
        expect do
          post vote_retro_item_path(retro, item)
        end.to change { item.reload.vote_count }.by(1)
      end

      it 'redirects to retro show page' do
        post vote_retro_item_path(retro, item)

        expect(response).to redirect_to(retro_path(retro))
      end
    end

    context 'Turbo Stream request' do
      it 'increments the vote count' do
        expect do
          post vote_retro_item_path(retro, item),
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        end.to change { item.reload.vote_count }.by(1)
      end

      it 'returns turbo stream response' do
        post vote_retro_item_path(retro, item),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'includes the item in the response' do
        post vote_retro_item_path(retro, item),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response.body).to include('turbo-stream')
      end
    end

    it 'allows multiple votes' do
      3.times do
        post vote_retro_item_path(retro, item),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end

      expect(item.reload.vote_count).to eq(3)
    end
  end

  describe 'POST /retros/:retro_slug/items/:id/highlight' do
    let!(:item) { retro.items.create!(description: 'Highlight me', category: 'happy') }

    context 'Turbo Stream request' do
      it 'sets the highlighted item on the retro' do
        post highlight_retro_item_path(retro, item),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(retro.reload.highlighted_item_id).to eq(item.id)
      end

      it 'returns turbo stream response' do
        post highlight_retro_item_path(retro, item),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe 'DELETE /retros/:retro_slug/items/:id/unhighlight' do
    let!(:item) { retro.items.create!(description: 'Unhighlight me', category: 'happy') }

    before do
      retro.update!(highlighted_item_id: item.id)
    end

    context 'Turbo Stream request' do
      it 'clears the highlighted item' do
        delete unhighlight_retro_item_path(retro, item),
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(retro.reload.highlighted_item_id).to be_nil
      end

      it 'returns turbo stream response' do
        delete unhighlight_retro_item_path(retro, item),
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe 'PATCH /retros/:retro_slug/items/:id/done' do
    let!(:item) { retro.items.create!(description: 'Mark me done', category: 'happy', done: false) }

    context 'Turbo Stream request' do
      it 'marks the item as done' do
        patch done_retro_item_path(retro, item),
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(item.reload.done).to be(true)
      end

      it 'returns turbo stream response' do
        patch done_retro_item_path(retro, item),
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end

    context 'when item is highlighted' do
      before do
        retro.update!(highlighted_item_id: item.id)
      end

      it 'clears the highlight when marking done' do
        patch done_retro_item_path(retro, item),
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(retro.reload.highlighted_item_id).to be_nil
      end
    end
  end
end
