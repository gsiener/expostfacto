# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hotwire::SessionsController', type: :request do
  describe 'GET /retros/:retro_slug/session/new' do
    let!(:private_retro) do
      Retro.create!(name: 'Private Retro', slug: 'private-retro', is_private: true, password: 'secret123')
    end

    it 'renders the login page' do
      get new_retro_session_path(private_retro)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /retros/:retro_slug/session' do
    context 'private retro with password' do
      let!(:private_retro) do
        Retro.create!(name: 'Private Retro', slug: 'private-retro', is_private: true, password: 'secret123')
      end

      context 'with correct password' do
        it 'authenticates and redirects to the retro' do
          post retro_session_path(private_retro), params: { password: 'secret123' }

          expect(response).to redirect_to(retro_path(private_retro))
        end

        it 'stores authentication in session' do
          post retro_session_path(private_retro), params: { password: 'secret123' }

          # Follow redirect and verify we can access the retro
          follow_redirect!
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(private_retro.name)
        end
      end

      context 'with incorrect password' do
        it 'renders the login page with error' do
          post retro_session_path(private_retro), params: { password: 'wrongpassword' }

          expect(response).to have_http_status(:unprocessable_content)
        end

        it 'shows error message' do
          post retro_session_path(private_retro), params: { password: 'wrongpassword' }

          expect(flash.now[:alert]).to eq('Incorrect password')
        end

        it 'does not authenticate the session' do
          post retro_session_path(private_retro), params: { password: 'wrongpassword' }

          # Try to access the retro directly
          get retro_path(private_retro)
          expect(response).to redirect_to(new_retro_session_path(private_retro))
        end
      end

      context 'with empty password' do
        it 'renders the login page with error' do
          post retro_session_path(private_retro), params: { password: '' }

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context 'public retro (no password)' do
      let!(:public_retro) do
        Retro.create!(name: 'Public Retro', slug: 'public-retro', is_private: false)
      end

      it 'authenticates without password' do
        post retro_session_path(public_retro), params: { password: '' }

        expect(response).to redirect_to(retro_path(public_retro))
      end
    end
  end

  describe 'DELETE /retros/:retro_slug/session' do
    let!(:private_retro) do
      Retro.create!(name: 'Private Retro', slug: 'private-retro', is_private: true, password: 'secret123')
    end

    it 'logs out and redirects to root' do
      # First authenticate
      post retro_session_path(private_retro), params: { password: 'secret123' }

      # Then logout
      delete retro_session_path(private_retro)

      expect(response).to redirect_to(root_path)
    end

    it 'clears authentication from session' do
      # First authenticate
      post retro_session_path(private_retro), params: { password: 'secret123' }

      # Verify we can access
      get retro_path(private_retro)
      expect(response).to have_http_status(:ok)

      # Logout
      delete retro_session_path(private_retro)

      # Try to access again
      get retro_path(private_retro)
      expect(response).to redirect_to(new_retro_session_path(private_retro))
    end
  end

  describe 'GET /join/:token (magic link)' do
    context 'with valid token' do
      let!(:retro_with_magic_link) do
        retro = Retro.create!(
          name: 'Magic Link Retro',
          slug: 'magic-link-retro',
          is_private: true,
          password: 'secret123'
        )
        retro.is_magic_link_enabled = true
        retro.save!
        retro
      end

      it 'authenticates and redirects to the retro' do
        get magic_link_path(token: retro_with_magic_link.join_token)

        expect(response).to redirect_to(retro_path(retro_with_magic_link))
      end

      it 'allows access to the retro after using magic link' do
        get magic_link_path(token: retro_with_magic_link.join_token)
        follow_redirect!

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(retro_with_magic_link.name)
      end
    end

    context 'with invalid token' do
      it 'redirects to root with error' do
        get magic_link_path(token: 'invalid-token-12345')

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Invalid or expired link')
      end
    end

    context 'with nonexistent token' do
      it 'redirects to root with error' do
        get magic_link_path(token: 'nonexistent-token-xyz')

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Invalid or expired link')
      end
    end
  end

  describe 'session persistence' do
    let!(:private_retro) do
      Retro.create!(name: 'Private Retro', slug: 'private-retro', is_private: true, password: 'secret123')
    end

    it 'maintains authentication across multiple requests' do
      # Authenticate
      post retro_session_path(private_retro), params: { password: 'secret123' }

      # Make multiple requests
      3.times do
        get retro_path(private_retro)
        expect(response).to have_http_status(:ok)
      end
    end

    it 'allows access to multiple private retros' do
      another_private_retro = Retro.create!(
        name: 'Another Private Retro',
        slug: 'another-private-retro',
        is_private: true,
        password: 'different123'
      )

      # Authenticate to first retro
      post retro_session_path(private_retro), params: { password: 'secret123' }
      get retro_path(private_retro)
      expect(response).to have_http_status(:ok)

      # Try to access second retro (should require auth)
      get retro_path(another_private_retro)
      expect(response).to redirect_to(new_retro_session_path(another_private_retro))

      # Authenticate to second retro
      post retro_session_path(another_private_retro), params: { password: 'different123' }
      get retro_path(another_private_retro)
      expect(response).to have_http_status(:ok)

      # First retro should still be accessible
      get retro_path(private_retro)
      expect(response).to have_http_status(:ok)
    end
  end
end
