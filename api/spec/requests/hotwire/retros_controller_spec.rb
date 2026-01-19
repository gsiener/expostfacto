# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hotwire::RetrosController', type: :request do
  describe 'GET / (index)' do
    it 'renders the index page successfully' do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Postfacto')
      expect(response.body).to include('Your Retrospectives')
    end

    it 'shows empty state when no retros exist' do
      get root_path

      expect(response.body).to include('No retrospectives yet')
      expect(response.body).to include('Create your first retro')
    end
  end

  describe 'GET /retros/new' do
    it 'renders the new retro form' do
      get new_retro_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Create a New Retro')
    end
  end

  describe 'POST /retros' do
    context 'with valid params' do
      let(:valid_params) do
        {
          retro: {
            name: 'Sprint 42 Retro',
            slug: 'sprint-42-retro'
          }
        }
      end

      it 'creates a new retro' do
        expect do
          post retros_path, params: valid_params
        end.to change(Retro, :count).by(1)
      end

      it 'redirects to the retro show page' do
        post retros_path, params: valid_params

        retro = Retro.last
        expect(response).to redirect_to(retro_path(retro))
      end

      it 'sets the flash notice' do
        post retros_path, params: valid_params

        expect(flash[:notice]).to eq('Retro created!')
      end

      it 'marks the retro as authenticated in the session' do
        post retros_path, params: valid_params

        retro = Retro.last
        follow_redirect!
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(retro.name)
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          retro: {
            name: '',
            slug: 'invalid slug with spaces!'
          }
        }
      end

      it 'does not create a retro with invalid slug' do
        expect do
          post retros_path, params: invalid_params
        end.not_to change(Retro, :count)
      end

      it 'renders the new form with errors' do
        post retros_path, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with duplicate slug' do
      let!(:existing_retro) { Retro.create!(name: 'Existing', slug: 'existing-slug') }

      it 'does not create a retro with duplicate slug' do
        expect do
          post retros_path, params: { retro: { name: 'New Retro', slug: 'existing-slug' } }
        end.not_to change(Retro, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'GET /retros/:slug' do
    let!(:retro) { Retro.create!(name: 'Test Retro', slug: 'test-retro') }

    context 'public retro' do
      it 'renders the retro show page' do
        get retro_path(retro)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(retro.name)
      end

      it 'displays the three columns (happy, meh, sad)' do
        get retro_path(retro)

        expect(response.body).to include('Happy')
        expect(response.body).to include('Meh')
        expect(response.body).to include('Sad')
      end

      it 'displays the action items section' do
        get retro_path(retro)

        expect(response.body).to include('Action Items')
      end
    end

    context 'with items' do
      let!(:happy_item) { retro.items.create!(description: 'Great teamwork', category: 'happy') }
      let!(:meh_item) { retro.items.create!(description: 'Could improve', category: 'meh') }
      let!(:sad_item) { retro.items.create!(description: 'Needs work', category: 'sad') }

      it 'displays the items' do
        get retro_path(retro)

        expect(response.body).to include('Great teamwork')
        expect(response.body).to include('Could improve')
        expect(response.body).to include('Needs work')
      end
    end

    context 'with action items' do
      let!(:action_item) { retro.action_items.create!(description: 'Schedule follow-up meeting') }

      it 'displays the action items' do
        get retro_path(retro)

        expect(response.body).to include('Schedule follow-up meeting')
      end
    end

    context 'private retro without authentication' do
      let!(:private_retro) do
        Retro.create!(name: 'Private Retro', slug: 'private-retro', is_private: true, password: 'secret123')
      end

      it 'redirects to the login page' do
        get retro_path(private_retro)

        expect(response).to redirect_to(new_retro_session_path(private_retro))
      end
    end

    context 'private retro with authentication' do
      let!(:private_retro) do
        Retro.create!(name: 'Private Retro', slug: 'private-retro', is_private: true, password: 'secret123')
      end

      it 'renders the retro when authenticated' do
        # First authenticate via session
        post retro_session_path(private_retro), params: { password: 'secret123' }
        expect(response).to redirect_to(retro_path(private_retro))

        get retro_path(private_retro)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(private_retro.name)
      end
    end
  end

  describe 'GET /retros/:slug/edit' do
    let!(:retro) { Retro.create!(name: 'Test Retro', slug: 'test-retro') }

    it 'renders the edit form' do
      get edit_retro_path(retro)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /retros/:slug' do
    let!(:retro) { Retro.create!(name: 'Test Retro', slug: 'test-retro') }

    context 'with valid params' do
      it 'updates the retro' do
        patch retro_path(retro), params: { retro: { name: 'Updated Name' } }

        expect(response).to redirect_to(retro_path(retro))
        expect(retro.reload.name).to eq('Updated Name')
      end

      it 'sets the flash notice' do
        patch retro_path(retro), params: { retro: { name: 'Updated Name' } }

        expect(flash[:notice]).to eq('Settings saved!')
      end
    end

    context 'with video link' do
      it 'updates the video link' do
        patch retro_path(retro), params: { retro: { video_link: 'https://zoom.us/j/123' } }

        expect(retro.reload.video_link).to eq('https://zoom.us/j/123')
      end
    end
  end

  describe 'POST /retros/:slug/archive' do
    let!(:retro) { Retro.create!(name: 'Test Retro', slug: 'test-retro') }
    let!(:item) { retro.items.create!(description: 'Test item', category: 'happy') }
    let!(:action_item) { retro.action_items.create!(description: 'Test action') }

    it 'archives the retro items' do
      expect do
        post archive_retro_path(retro)
      end.to change(Archive, :count).by(1)
    end

    it 'redirects to the retro show page' do
      post archive_retro_path(retro)

      expect(response).to redirect_to(retro_path(retro))
    end

    it 'sets the flash notice' do
      post archive_retro_path(retro)

      expect(flash[:notice]).to eq('Archived!')
    end
  end

  describe 'retro not found' do
    it 'redirects to root with alert when retro does not exist' do
      get retro_path(slug: 'non-existent-retro')

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Retro not found')
    end
  end
end
