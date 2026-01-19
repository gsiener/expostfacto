# frozen_string_literal: true

# Custom middleware to enrich OpenTelemetry spans with business context
class OpentelemetryMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless instrumentation_enabled?

    request = ActionDispatch::Request.new(env)
    span = OpenTelemetry::Trace.current_span

    # Add HTTP attributes
    add_http_attributes(span, request, env)

    # Add business context
    add_business_context(span, request)

    # Call the application
    begin
      status, headers, response = @app.call(env)
      span.set_attribute('http.status_code', status)
      [status, headers, response]
    rescue StandardError => e
      record_exception(span, e, request)
      raise
    end
  end

  private

  def instrumentation_enabled?
    ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true'
  end

  def add_http_attributes(span, request, env)
    # HTTP semantic conventions
    span.set_attribute('http.route', env['action_dispatch.request.path_parameters']&.dig(:controller))
    span.set_attribute('http.user_agent', request.user_agent) if request.user_agent
    span.set_attribute('http.request_id', request.request_id) if request.request_id
    span.set_attribute('http.method', request.request_method)
    span.set_attribute('http.target', request.fullpath)
    span.set_attribute('http.scheme', request.scheme)
    span.set_attribute('http.host', request.host)
  end

  def add_business_context(span, request)
    # Extract retro slug from path
    if request.path =~ %r{/retros/([^/]+)}
      retro_slug = ::Regexp.last_match(1)
      span.set_attribute('retro.slug', retro_slug)
    end

    # Add session information if available
    if request.session && request.session[:user_id]
      span.set_attribute('user.authenticated', true)
      span.set_attribute('user.id', request.session[:user_id])
    else
      span.set_attribute('user.authenticated', false)
    end
  end

  def record_exception(span, exception, request)
    # Record the exception on the span
    span.record_exception(exception)
    span.status = OpenTelemetry::Trace::Status.error("Unhandled exception: #{exception.class.name}")

    # Add additional context about the exception
    span.set_attribute('exception.escaped', true)
    span.set_attribute('error.handled', false)
    span.set_attribute('exception.request_id', request.request_id) if request.request_id
  end
end
