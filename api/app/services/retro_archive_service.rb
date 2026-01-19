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
module RetroArchiveService
  def self.archive(retro, archived_at, send_archive_email)
    return archive_without_instrumentation(retro, archived_at, send_archive_email) unless instrumentation_enabled?

    tracer = OpenTelemetry.tracer_provider.tracer('postfacto.archive')
    tracer.in_span('archive.retro') do |span|
      # Add retro attributes
      span.set_attribute('retro.id', retro.id)
      span.set_attribute('retro.slug', retro.slug)
      span.set_attribute('archive.send_email', send_archive_email)
      span.set_attribute('archive.timestamp', archived_at.iso8601)

      # Create archive
      archive = retro.archives.create!
      span.set_attribute('archive.id', archive.id)

      # Archive items and get count
      items_count = mark_retro_items_archived(retro, archive, archived_at)
      span.set_attribute('archive.items_count', items_count)

      persist_send_archive_email_preference(retro, send_archive_email)

      # Send emails if requested
      if send_archive_email && retro.user
        send_emails(retro, archive)
        span.add_event('archive_email_queued', attributes: {
                         'email.recipient' => retro.user.email,
                         'archive.id' => archive.id
                       })
      end

      span.status = OpenTelemetry::Trace::Status.ok
    end
  end

  def self.archive_without_instrumentation(retro, archived_at, send_archive_email)
    archive = retro.archives.create!
    mark_retro_items_archived(retro, archive, archived_at)

    persist_send_archive_email_preference(retro, send_archive_email)

    send_emails(retro, archive) if send_archive_email && retro.user
  end

  def self.instrumentation_enabled?
    ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true' &&
      defined?(OpenTelemetry)
  end

  class << self
    private

    def persist_send_archive_email_preference(retro, send_archive_email_preference)
      retro.update!(send_archive_email: send_archive_email_preference)
    end

    def mark_retro_items_archived(retro, archive, archived_at)
      archive_data = { archived_at: archived_at, archived: true, archive_id: archive.id }
      items_count = retro.items.where(archived: false).update_all(archive_data)
      action_items_count = retro.action_items.where(archived: false, done: true).update_all(archive_data)
      retro.update!(highlighted_item_id: nil)

      items_count + action_items_count
    end

    def send_emails(retro, archive)
      if ARCHIVE_EMAILS
        ArchivedMailer.archived_email(retro, archive, retro.user, FROM_ADDRESS).deliver_now
      end
    end
  end
end
