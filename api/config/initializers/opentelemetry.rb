# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

# Only initialize OpenTelemetry if explicitly enabled
return unless ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true'

# Configure OTLP exporter via environment variables (required by the gem)
honeycomb_headers = "x-honeycomb-team=#{ENV.fetch('HONEYCOMB_API_KEY', '')}," \
                    "x-honeycomb-dataset=#{ENV.fetch('HONEYCOMB_DATASET', 'postfacto')}"
ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] ||= ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', 'https://api.honeycomb.io')
ENV['OTEL_EXPORTER_OTLP_HEADERS'] ||= honeycomb_headers
ENV['OTEL_EXPORTER_OTLP_COMPRESSION'] ||= 'gzip'

begin
  OpenTelemetry::SDK.configure do |c|
    # Service identification
    service_name = ENV.fetch('OTEL_SERVICE_NAME', 'postfacto')
    service_version = ENV.fetch('SERVICE_VERSION', '1.0.0')
    environment = ENV.fetch('RAILS_ENV', 'development')

    # Service name via attribute
    c.service_name = service_name
    c.service_version = service_version

    # Resource attributes
    c.resource = OpenTelemetry::SDK::Resources::Resource.create(
      'deployment.environment' => environment,
      'telemetry.sdk.language' => 'ruby',
      'telemetry.sdk.name' => 'opentelemetry'
    )

    # Add OTLP exporter with batch processor
    c.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new
      )
    )

    # Use all available instrumentations with default settings
    c.use_all
  end
rescue StandardError => e
  Rails.logger.error "OpenTelemetry initialization failed: #{e.class}: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
  raise
end

# Log initialization for debugging
Rails.logger.info "OpenTelemetry initialized: service=#{ENV.fetch('OTEL_SERVICE_NAME', 'postfacto')}, " \
                  "environment=#{ENV.fetch('RAILS_ENV', 'development')}, " \
                  "endpoint=#{ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)}"

# Initialize metrics collector after Rails finishes loading
# Rails.application.config.after_initialize do
#   if ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true'
#     TelemetryMetricsCollector.initialize_metrics
#   end
# end
