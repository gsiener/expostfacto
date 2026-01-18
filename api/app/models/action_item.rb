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
class ActionItem < ActiveRecord::Base
  include Ransackable

  belongs_to :retro, optional: true
  belongs_to :archive, optional: true

  validates :description, presence: true

  # Broadcast real-time updates via Turbo Streams to the retro
  broadcasts_to :retro, inserts_by: :prepend, target: 'action-items'

  # Override to_partial_path to point to the Hotwire partial
  def to_partial_path
    'hotwire/action_items/action_item'
  end

  ransackable attributes: %w[id description done created_at updated_at archived_at archived retro_id archive_id],
              associations: %w[archive retro]
end
