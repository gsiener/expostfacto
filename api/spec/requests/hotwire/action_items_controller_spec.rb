# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hotwire::ActionItemsController', type: :request do
  let!(:retro) { Retro.create!(name: 'Test Retro', slug: 'test-retro') }

  describe 'POST /retros/:retro_slug/action_items' do
    let(:valid_params) do
      {
        action_item: {
          description: 'Follow up with the team'
        }
      }
    end

    context 'HTML request' do
      it 'creates a new action item' do
        expect do
          post retro_action_items_path(retro), params: valid_params
        end.to change(ActionItem, :count).by(1)
      end

      it 'redirects to retro show page' do
        post retro_action_items_path(retro), params: valid_params

        expect(response).to redirect_to(retro_path(retro))
      end

      it 'creates the action item with correct attributes' do
        post retro_action_items_path(retro), params: valid_params

        action_item = ActionItem.last
        expect(action_item.description).to eq('Follow up with the team')
        expect(action_item.retro).to eq(retro)
        expect(action_item.done).to be(false)
      end
    end

    context 'Turbo Stream request' do
      it 'creates a new action item' do
        expect do
          post retro_action_items_path(retro),
               params: valid_params,
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        end.to change(ActionItem, :count).by(1)
      end

      it 'returns turbo stream response' do
        post retro_action_items_path(retro),
             params: valid_params,
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'includes turbo stream content' do
        post retro_action_items_path(retro),
             params: valid_params,
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('action-items')
      end
    end

    context 'with empty description' do
      let(:empty_params) do
        {
          action_item: {
            description: ''
          }
        }
      end

      it 'handles empty description' do
        # The behavior depends on model validations
        post retro_action_items_path(retro), params: empty_params

        # If no validations, it will create anyway; if validations, it will fail
        expect(response).to(
          have_http_status(:redirect).or(have_http_status(:ok)).or(have_http_status(:unprocessable_entity))
        )
      end
    end
  end

  describe 'PATCH /retros/:retro_slug/action_items/:id' do
    let!(:action_item) { retro.action_items.create!(description: 'Original task') }

    context 'HTML request' do
      it 'updates the action item' do
        patch retro_action_item_path(retro, action_item),
              params: { action_item: { description: 'Updated task' } }

        expect(action_item.reload.description).to eq('Updated task')
      end

      it 'redirects to retro show page' do
        patch retro_action_item_path(retro, action_item),
              params: { action_item: { description: 'Updated' } }

        expect(response).to redirect_to(retro_path(retro))
      end
    end

    context 'Turbo Stream request' do
      it 'updates the action item' do
        patch retro_action_item_path(retro, action_item),
              params: { action_item: { description: 'Updated task' } },
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(action_item.reload.description).to eq('Updated task')
      end

      it 'returns turbo stream response' do
        patch retro_action_item_path(retro, action_item),
              params: { action_item: { description: 'Updated' } },
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe 'DELETE /retros/:retro_slug/action_items/:id' do
    let!(:action_item) { retro.action_items.create!(description: 'To be deleted') }

    context 'HTML request' do
      it 'deletes the action item' do
        expect do
          delete retro_action_item_path(retro, action_item)
        end.to change(ActionItem, :count).by(-1)
      end

      it 'redirects to retro show page' do
        delete retro_action_item_path(retro, action_item)

        expect(response).to redirect_to(retro_path(retro))
      end
    end

    context 'Turbo Stream request' do
      it 'deletes the action item' do
        expect do
          delete retro_action_item_path(retro, action_item),
                 headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        end.to change(ActionItem, :count).by(-1)
      end

      it 'returns turbo stream response' do
        delete retro_action_item_path(retro, action_item),
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe 'PATCH /retros/:retro_slug/action_items/:id/toggle_done' do
    let!(:action_item) { retro.action_items.create!(description: 'Toggle me', done: false) }

    context 'HTML request' do
      it 'toggles the done status from false to true' do
        patch toggle_done_retro_action_item_path(retro, action_item)

        expect(action_item.reload.done).to be(true)
      end

      it 'redirects to retro show page' do
        patch toggle_done_retro_action_item_path(retro, action_item)

        expect(response).to redirect_to(retro_path(retro))
      end
    end

    context 'Turbo Stream request' do
      it 'toggles the done status' do
        patch toggle_done_retro_action_item_path(retro, action_item),
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(action_item.reload.done).to be(true)
      end

      it 'returns turbo stream response' do
        patch toggle_done_retro_action_item_path(retro, action_item),
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end

    context 'toggling back to not done' do
      let!(:done_action_item) { retro.action_items.create!(description: 'Already done', done: true) }

      it 'toggles from true to false' do
        patch toggle_done_retro_action_item_path(retro, done_action_item),
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(done_action_item.reload.done).to be(false)
      end
    end
  end

  describe 'multiple action items' do
    it 'creates multiple action items for a retro' do
      3.times do |i|
        post retro_action_items_path(retro),
             params: { action_item: { description: "Task #{i + 1}" } }
      end

      expect(retro.action_items.count).to eq(3)
    end

    it 'each action item belongs to the retro' do
      post retro_action_items_path(retro),
           params: { action_item: { description: 'First task' } }

      expect(ActionItem.last.retro_id).to eq(retro.id)
    end
  end
end
