# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hotwire::ArchivesController', type: :request do
  let!(:retro) { Retro.create!(name: 'Test Retro', slug: 'test-retro') }

  # Helper method to create an archive with items using the service
  def create_archive_with_items(target_retro, items_data: [], action_items_data: [])
    # Create items on the retro first
    items_data.each do |item_data|
      target_retro.items.create!(
        description: item_data[:description],
        category: item_data[:category],
        vote_count: item_data[:vote_count] || 0,
        done: item_data[:done] || false
      )
    end

    action_items_data.each do |ai_data|
      target_retro.action_items.create!(
        description: ai_data[:description],
        done: ai_data[:done] || false
      )
    end

    # Archive the retro (this moves items to the archive)
    RetroArchiveService.archive(target_retro, Time.current, false)

    target_retro.archives.last
  end

  describe 'GET /retros/:retro_slug/archives' do
    context 'with no archives' do
      it 'renders the archives index page' do
        get retro_archives_path(retro)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Past Retrospectives')
      end

      it 'shows empty state message' do
        get retro_archives_path(retro)

        expect(response.body).to include('No archives yet')
      end
    end

    context 'with archives' do
      let!(:archive) do
        create_archive_with_items(
          retro,
          items_data: [
            { description: 'Happy item', category: 'happy', vote_count: 3 },
            { description: 'Sad item', category: 'sad', vote_count: 1 }
          ],
          action_items_data: [
            { description: 'Follow up', done: true }
          ]
        )
      end

      it 'renders the archives list' do
        get retro_archives_path(retro)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Past Retrospectives')
      end

      it 'displays archive dates' do
        get retro_archives_path(retro)

        expect(response.body).to include(archive.created_at.strftime('%B %d, %Y'))
      end
    end

    context 'with multiple archives' do
      before do
        3.times do |i|
          retro.items.create!(description: "Item #{i}", category: 'happy')
          RetroArchiveService.archive(retro, Time.current, false)
        end
      end

      it 'displays all archives' do
        get retro_archives_path(retro)

        expect(response).to have_http_status(:ok)
        expect(retro.archives.count).to eq(3)
      end
    end

    context 'private retro' do
      let!(:private_retro) do
        Retro.create!(name: 'Private Retro', slug: 'private-retro', is_private: true, password: 'secret123')
      end

      it 'requires authentication to view archives' do
        get retro_archives_path(private_retro)

        expect(response).to redirect_to(new_retro_session_path(private_retro))
      end

      it 'allows access after authentication' do
        post retro_session_path(private_retro), params: { password: 'secret123' }

        get retro_archives_path(private_retro)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Past Retrospectives')
      end
    end
  end

  describe 'GET /retros/:retro_slug/archives/:id' do
    let!(:archive) do
      create_archive_with_items(
        retro,
        items_data: [
          { description: 'Great teamwork', category: 'happy', vote_count: 5 },
          { description: 'Need better communication', category: 'meh', vote_count: 2 },
          { description: 'Technical debt', category: 'sad', vote_count: 1 }
        ],
        action_items_data: [
          { description: 'Schedule retrospective meeting', done: true },
          { description: 'Update documentation', done: false }
        ]
      )
    end

    it 'renders the archive show page' do
      get retro_archive_path(retro, archive)

      expect(response).to have_http_status(:ok)
    end

    it 'displays the retro name' do
      get retro_archive_path(retro, archive)

      expect(response.body).to include(retro.name)
    end

    it 'displays the archive date' do
      get retro_archive_path(retro, archive)

      expect(response.body).to include(archive.created_at.strftime('%B %d, %Y'))
    end

    it 'displays the three columns' do
      get retro_archive_path(retro, archive)

      expect(response.body).to include('Happy')
      expect(response.body).to include('Meh')
      expect(response.body).to include('Sad')
    end

    it 'displays archived items' do
      get retro_archive_path(retro, archive)

      expect(response.body).to include('Great teamwork')
      expect(response.body).to include('Need better communication')
      expect(response.body).to include('Technical debt')
    end

    it 'displays action items section' do
      get retro_archive_path(retro, archive)

      expect(response.body).to include('Action Items')
      # Only done action items are archived by RetroArchiveService
      expect(response.body).to include('Schedule retrospective meeting')
    end

    it 'shows read-only indicator' do
      get retro_archive_path(retro, archive)

      expect(response.body).to include('Read Only')
    end

    context 'archive not found' do
      it 'returns not found status' do
        get retro_archive_path(retro, id: 99_999)

        # Request specs catch the exception and return appropriate HTTP status
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'private retro' do
      let!(:private_retro) do
        Retro.create!(name: 'Private Retro', slug: 'private-retro', is_private: true, password: 'secret123')
      end
      let!(:private_archive) do
        create_archive_with_items(
          private_retro,
          items_data: [{ description: 'Private item', category: 'happy' }]
        )
      end

      it 'requires authentication to view archive' do
        get retro_archive_path(private_retro, private_archive)

        expect(response).to redirect_to(new_retro_session_path(private_retro))
      end

      it 'allows access after authentication' do
        post retro_session_path(private_retro), params: { password: 'secret123' }

        get retro_archive_path(private_retro, private_archive)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Private item')
      end
    end
  end

  describe 'archives belong to correct retro' do
    let!(:other_retro) { Retro.create!(name: 'Other Retro', slug: 'other-retro') }
    let!(:archive) do
      create_archive_with_items(
        retro,
        items_data: [{ description: 'My item', category: 'happy' }]
      )
    end

    it 'cannot access archive from different retro' do
      get retro_archive_path(other_retro, archive)

      # Request specs catch the exception and return appropriate HTTP status
      expect(response).to have_http_status(:not_found)
    end
  end
end
