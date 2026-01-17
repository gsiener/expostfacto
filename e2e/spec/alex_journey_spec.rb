#
# Postfacto, a free, open-source and self-hosted retro tool aimed at helping
# remote teams.
#
# Copyright (C) 2016 - Present Pivotal Software, Inc.
#
# This program is free software: you can redistribute it and/or modify
#
# it under the terms of the GNU Affero General Public License as
#
# published by the Free Software Foundation, either version 3 of the
#
# License, or (at your option) any later version.
#
#
#
# This program is distributed in the hope that it will be useful,
#
# but WITHOUT ANY WARRANTY; without even the implied warranty of
#
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#
# GNU Affero General Public License for more details.
#
#
#
# You should have received a copy of the GNU Affero General Public License
#
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
require 'spec_helper'

describe 'Alex (Admin)', type: :feature, js: true do
  # Setup test users once before all admin tests
  before(:all) do
    # Create users needed for admin tests
    register('user-with-retros')
    create_public_retro
    logout

    register('user-without-retros')
    logout

    register('old-retro-owner')
    create_public_retro('Retro needs new owner')
    register('new-retro-owner')
    logout

    register('banished-user')
    create_public_retro('Banished user retro')
    logout

    register('unwanting-retro-owner')
    create_public_retro('Not wanted retro')
    logout

    register('dead-retro-user')
    create_public_retro('Dead retro')
    logout
  end

  before(:each) do
    login_as_admin
  end

  describe 'on the users page' do
    specify 'cannot delete a user who has retros' do
      click_on 'Users'
      fill_in 'q_email', with: 'user-with-retros'
      click_on 'Filter'

      click_on 'Delete'
      accept_confirm

      expect(page).to have_content 'user-with-retros'
    end

    specify 'can delete a user without retros' do
      click_on 'Users'

      expect(page).to have_content 'user-without-retros'

      fill_in 'Email', with: 'user-without-retros'
      click_on 'Filter'
      click_on 'Delete'

      accept_confirm

      expect(page).to_not have_content 'user-without-retros'
    end
  end

  describe 'on the retros page' do
    specify 'can create a new private retro' do
      click_on 'Retros'
      click_on 'New Retro'

      fill_in 'retro_name', with: 'My awesome new private retro'
      fill_in 'retro_slug', with: 'my-awesome-new-private-retro'
      fill_in 'retro_password', with: 'secret'

      click_on 'Create Retro'

      visit RETRO_APP_BASE_URL + '/retros/my-awesome-new-private-retro'

      fill_in 'Password', with: 'secret'
      click_button 'Login'

      expect(page).to have_content('My awesome new private retro')
    end

    specify 'can create a new public retro' do
      click_on 'Retros'
      click_on 'New Retro'

      fill_in 'retro_name', with: 'My awesome new public retro'
      fill_in 'retro_slug', with: 'my-awesome-new-public-retro'
      uncheck 'retro_is_private'

      click_on 'Create Retro'

      visit RETRO_APP_BASE_URL + '/retros/my-awesome-new-public-retro'

      expect(page).to have_content('My awesome new public retro')
    end

    specify 'can change the owner to another user' do
      click_on 'Retros'

      within('tr', text: 'Retro needs new owner') do
        click_on 'Edit'
      end

      expect(page).to have_content 'Owner Email'
      expect(find_field('retro_owner_email').value).to eq 'old-retro-owner@example.com'

      fill_in 'retro_owner_email', with: 'new-retro-owner@example.com'

      click_on 'Update Retro'

      first(:link, 'Retros').click
      fill_in 'q_name', with: 'Retro needs new owner'
      click_on 'Filter'

      click_on 'Edit'

      expect(page).to have_field('Owner Email', with: 'new-retro-owner@example.com')
    end

    specify 'can remove an owner from a retro' do
      click_on 'Retros'

      within('tr', text: 'Banished user retro') do
        click_link 'Edit'
      end

      fill_in 'Owner Email', with: ''

      click_on 'Update Retro'

      first(:link, 'Retros').click

      within('tr', text: 'Banished user retro') do
        click_link 'Edit'
      end

      expect(page).to have_field('Owner Email', with: '')
    end

    specify 'shows error when new owner email does not match any user' do
      click_on 'Retros'

      within('tr', text: 'Not wanted retro') do
        click_on 'Edit'
      end

      fill_in 'Owner Email', with: 'wrong@example.com'

      click_on 'Update Retro'
      expect(page).to have_content 'Could not change owners. User not found by email.'
    end

    specify 'can delete a retro' do
      click_on 'Retros'

      within('tr', text: 'Dead retro') do
        click_on 'Delete'
      end

      accept_alert 'Are you sure you want to delete this?'

      expect(page).to have_content('Retros')
      expect(page).to_not have_content('Dead retro')
    end
  end
end
