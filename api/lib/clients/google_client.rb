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
require 'httpx'

class GoogleClient
  def initialize(url, hosted_domain)
    @url = url
    @hosted_domain = hosted_domain
  end

  def get_user!(access_token)
    return get_user_without_instrumentation!(access_token) unless instrumentation_enabled?

    tracer = OpenTelemetry.tracer_provider.tracer('postfacto.http_client')
    tracer.in_span('http.google_oauth.get_user', kind: :client) do |span|
      # Add HTTP attributes
      span.set_attribute('http.method', 'GET')
      span.set_attribute('http.url', @url)
      span.set_attribute('http.target', 'google_oauth')

      begin
        response = HTTPX.get(@url, headers: { 'Authorization' => "Bearer #{access_token}" })

        # Add response attributes
        span.set_attribute('http.status_code', response.status)
        span.set_attribute('http.response_content_length', response.body.to_s.bytesize)

        raise GetUserFailed.new unless response.status == 200

        user = JSON.parse(response.body.to_s, symbolize_names: true)

        validate_hosted_domain user

        # Add user domain if available
        span.set_attribute('user.domain', user[:hd]) if user[:hd]

        span.status = OpenTelemetry::Trace::Status.ok
        user
      rescue InvalidUserDomain => e
        span.record_exception(e)
        span.status = OpenTelemetry::Trace::Status.error('Invalid user domain')
        span.set_attribute('error.type', 'InvalidUserDomain')
        raise e
      rescue GetUserFailed => e
        span.record_exception(e)
        span.status = OpenTelemetry::Trace::Status.error('Failed to get user from Google')
        span.set_attribute('error.type', 'GetUserFailed')
        raise e
      rescue StandardError => e
        span.record_exception(e)
        span.status = OpenTelemetry::Trace::Status.error('Unexpected error')
        raise GetUserFailed.new
      end
    end
  end

  def get_user_without_instrumentation!(access_token)
    response = HTTPX.get(@url, headers: { 'Authorization' => "Bearer #{access_token}" })

    raise GetUserFailed.new unless response.status == 200

    user = JSON.parse(response.body.to_s, symbolize_names: true)

    validate_hosted_domain user

    user
  rescue InvalidUserDomain => e
    raise e
  rescue StandardError
    raise GetUserFailed.new
  end

  def instrumentation_enabled?
    ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true' &&
      defined?(OpenTelemetry)
  end

  def validate_hosted_domain(user)
    if @hosted_domain && (user[:hd] != @hosted_domain)
      raise InvalidUserDomain.new
    end
  end

  class GetUserFailed < StandardError
  end

  class InvalidUserDomain < StandardError
  end
end
