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
require 'pry-byebug'

context 'A Journey Of Two Participants', type: :feature, js: true do
  # This file tests REAL-TIME SYNC between multiple browser sessions.
  # Basic CRUD operations are tested in felicity_journey_spec.rb

  specify 'real-time sync: items and actions appear across browsers' do
    retro_url = in_browser(:felicity) do
      register('two-participants-felicity-user')
      create_private_retro
    end

    # Peter joins with password
    in_browser(:peter) do
      visit retro_url
      fill_in 'Password', with: 'password'
      find('.retro-form-submit').click
      expect(page).to have_css('.retro-item-list')
    end

    # Peter creates an item - Felicity should see it
    in_browser(:peter) do
      fill_in("I'm glad that...", with: 'synced happy item')
      find('.column-happy textarea.retro-item-add-input').native.send_keys(:return)
      expect(page).to have_content 'synced happy item'
    end

    in_browser(:felicity) do
      expect(page).to have_content 'synced happy item'
    end

    # Felicity votes - Peter should see updated count
    in_browser(:felicity) do
      within('.retro-item', text: 'synced happy item') do
        find('.item-vote-submit').click
        expect(page).to have_content('1')
      end
    end

    in_browser(:peter) do
      within('.retro-item', text: 'synced happy item') do
        expect(page).to have_content('1')
      end
    end

    # Felicity highlights - Peter sees highlight
    in_browser(:felicity) do
      select_item('synced happy item')
      expect(page).to have_css('.highlight .item-text', text: 'synced happy item')
    end

    in_browser(:peter) do
      expect(page).to have_css('.highlight .item-text', text: 'synced happy item')
    end

    # Felicity marks done - Peter sees discussed state
    in_browser(:felicity) do
      within('div.retro-item', text: 'synced happy item') do
        find('.item-done').click
      end
      expect(page).to have_css('.retro-item.discussed .item-text', text: 'synced happy item')
    end

    in_browser(:peter) do
      expect(page).to have_css('.retro-item.discussed .item-text', text: 'synced happy item')
    end

    # Felicity adds action - Peter sees it
    in_browser(:felicity) do
      fill_in("Add an action item", with: 'synced action')
      find('.retro-action-header .retro-item-add-input').native.send_keys(:return)
      expect(page).to have_content('synced action')
    end

    in_browser(:peter) do
      expect(page).to have_content('synced action')
    end

    # Felicity archives - Peter's board clears
    in_browser(:felicity) do
      click_menu_item 'Archive this retro'
      click_button 'Archive & send email'
    end

    in_browser(:peter) do
      expect(page).to_not have_css('.retro-item')
    end
  end

  specify 'sharing a retro url' do
    retro_share_url = in_browser(:felicity) do
      register('two-participants-sharing-felicity-user')
      retro_url = create_private_retro('A retro only for people with the password')
      visit retro_url

      get_share_url
    end

    in_browser(:peter) do
      visit retro_share_url
      expect(page).to have_content 'A retro only for people with the password'
    end
  end

  specify 'Public retros cannot be archived without password' do
    retro_url = ''
    view_all_archives_url = ''
    view_archive_url = ''
    in_browser(:felicity) do
      register('public-cannot-archived-without-password-user')
      visit_retro_new_page
      fill_in 'Team name', with: 'My Retro'
      fill_in 'team-name', with: Time.now.strftime('%Y%m%d%H%M%s')
      fill_in 'Create password', with: 'password'
      find('#retro_is_private', visible: :all).click

      click_button 'Create'
      expect(page).to have_content 'My Retro'
      retro_url = current_url

      fill_in("I'm wondering about...", with: 'this is a meh item')
      find('.column-meh textarea.retro-item-add-input').native.send_keys(:return)

      click_menu_item 'Archive this retro'
      expect(page).to have_content "You're about to archive this retro."
      click_button 'Archive & send email'
      click_menu_item 'View archives'
      view_all_archives_url = current_url

      find('.archive-link a').click
      view_archive_url = current_url
    end

    in_browser(:peter) do
      visit retro_url
      fill_in("I'm glad that...", with: 'this is a happy item')
      find('.column-happy textarea.retro-item-add-input').native.send_keys(:return)
      expect(page).to have_content 'this is a happy item'

      # Ensure view archive pages are password protected
      visit view_all_archives_url
      expect(page).to have_content "Psst... what's the password?"
      visit view_archive_url
      expect(page).to have_content "Psst... what's the password?"

      # Archive the retro by entering password
      visit retro_url
      click_menu_item 'Archive this retro'
      click_button 'Archive & send email'

      fill_in 'Password', with: 'password'
      click_button 'Login'

      click_menu_item 'Archive this retro'
      click_button 'Archive & send email'

      expect(page).to have_content('Archived!')
    end
  end

  specify 'Public retro settings cannot be changed without password' do
    retro_url = ''

    in_browser(:felicity) do
      register('public-cannot-be-changed-without-password')
      visit_retro_new_page
      retro_url = create_public_retro('My Retro')

      click_menu_item 'Retro settings'

      settings_url = current_url
      fill_in('name', with: 'My New Retro')
      click_button('Save changes')

      visit retro_url
      expect(page).to have_content('My New Retro')
    end

    in_browser(:peter) do
      visit retro_url
      click_menu_item 'Retro settings'

      fill_in 'Password', with: 'password'
      click_button 'Login'

      click_menu_item 'Retro settings'

      fill_in('name', with: 'My Old Retro')
      click_button('Save changes')

      visit retro_url
      expect(page).to have_content('My Old Retro')
    end
  end

  specify 'Changing retro password and re-login for Peter' do
    retro_url = ''

    in_browser(:felicity) do
      register('changing-password-re-login')
      visit_retro_new_page
      fill_in 'Team name', with: 'My Retro'
      fill_in 'team-name', with: Time.now.strftime('%Y%m%d%H%M%s')
      fill_in 'Create password', with: 'current_password'

      click_button 'Create'
      expect(page).to have_content 'My Retro'

      retro_url = current_url
    end

    in_browser(:peter) do
      visit retro_url

      fill_in 'Password', with: 'current_password'
      click_button 'Login'

      expect(page).to have_css('.retro-item-list')
    end

    in_browser(:felicity) do
      click_menu_item 'Retro settings'

      click_link 'Change password'

      fill_in('current_password', with: 'current_password')
      fill_in('new_password', with: 'new_password')
      fill_in('confirm_new_password', with: 'new_password')

      click_button('Save new password')

      expect(page).to have_content 'Settings'
      expect(page).to have_content 'Password changed'

      click_button 'Back'

      fill_in("I'm glad that...", with: 'this is a happy item')
      find('.column-happy textarea.retro-item-add-input').native.send_keys(:return)
    end

    sleep(1)

    in_browser(:peter) do
      expect(page).not_to have_content 'this is a happy item'
      expect(page).to have_content 'The owner of this retro has chosen to protect it with a password.'

      fill_in 'Password', with: 'new_password'
      click_button 'Login'

      expect(page).to have_css('.retro-item-list')
      expect(page).to have_content 'this is a happy item'
    end
  end
end
