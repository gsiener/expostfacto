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

require 'security/auth_token'

class ApplicationController < ActionController::Base
  protect_from_forgery
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from StandardError, with: :handle_standard_error

  private

  def record_not_found
    render json: {}, status: :not_found
  end

  def handle_standard_error(exception)
    # Let ActiveRecord::RecordNotFound be handled by its specific handler
    raise exception if exception.is_a?(ActiveRecord::RecordNotFound)

    record_exception_in_otel(exception)
    log_exception(exception)
    render_error_response(exception)
  end

  def record_exception_in_otel(exception)
    return unless ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true'
    return unless defined?(OpenTelemetry)

    span = OpenTelemetry::Trace.current_span
    return unless span

    span.record_exception(exception)
    span.status = OpenTelemetry::Trace::Status.error("Unhandled error: #{exception.class.name}")
    span.set_attribute('exception.escaped', false)
    span.set_attribute('error.handled', true)
    span.set_attribute('request.id', request.request_id) if request.request_id
    span.set_attribute('user.authenticated', session[:user_id].present?)
    span.set_attribute('exception.message', exception.message)
    span.set_attribute('exception.class', exception.class.name)
  end

  def log_exception(exception)
    Rails.logger.error "Unhandled error: #{exception.class.name} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
  end

  def render_error_response(exception)
    if Rails.env.production?
      render json: { error: 'Internal server error' }, status: :internal_server_error
    else
      render json: {
        error: exception.message,
        class: exception.class.name,
        backtrace: exception.backtrace&.first(10)
      }, status: :internal_server_error
    end
  end
end
