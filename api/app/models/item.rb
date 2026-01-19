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
class Item < ActiveRecord::Base
  include Ransackable
  include OpentelemetryInstrumentedModel

  belongs_to :retro, optional: true
  belongs_to :archive, optional: true

  enum :category, { happy: 'happy', meh: 'meh', sad: 'sad' }

  validates :description, presence: true
  validates :category, presence: true

  # Broadcast real-time updates via Turbo Streams to the retro
  broadcasts_to :retro, inserts_by: :prepend, target: ->(item) { "#{item.category}-items" }

  # Override to_partial_path to point to the Hotwire partial
  def to_partial_path
    'hotwire/items/item'
  end

  # Query scopes for reducing N+1 queries and improving code organization
  scope :active, -> { where(archived: false) }
  scope :for_discussion, -> { active.where(done: false) }
  scope :by_votes, -> { order(vote_count: :desc) }
  scope :by_created_at, -> { order(created_at: :asc) }

  # Returns items organized by category for efficient retrieval
  def self.grouped_by_category
    {
      happy: happy.by_created_at,
      meh: meh.by_created_at,
      sad: sad.by_created_at
    }
  end

  before_destroy :clear_highlight

  ransackable attributes: %w[
    id description category vote_count done created_at updated_at archived_at archived retro_id archive_id
  ], associations: %w[archive retro]

  def vote!
    increment! :vote_count
  end

  private

  def add_model_attributes(span)
    span.set_attribute('item.id', id) if id.present?
    span.set_attribute('item.category', category)
    span.set_attribute('item.vote_count', vote_count)
    span.set_attribute('item.done', done)
    span.set_attribute('retro.id', retro_id) if retro_id.present?
  end

  def clear_highlight
    return unless retro&.highlighted_item_id == id

    retro.update!(highlighted_item_id: nil)
  end
end
