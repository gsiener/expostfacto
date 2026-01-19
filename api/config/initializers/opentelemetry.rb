# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

# Only initialize OpenTelemetry if explicitly enabled
return unless ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true'

begin
  OpenTelemetry::SDK.configure do |c|
    # Service identification
    service_name = ENV.fetch('OTEL_SERVICE_NAME', 'postfacto')
    service_version = ENV.fetch('SERVICE_VERSION', '1.0.0')
    environment = ENV.fetch('RAILS_ENV', 'development')

    # Resource attributes following semantic conventions
    c.resource = OpenTelemetry::SDK::Resources::Resource.create(
      OpenTelemetry::SemanticConventions::Resource::SERVICE_NAME => service_name,
      OpenTelemetry::SemanticConventions::Resource::SERVICE_VERSION => service_version,
      OpenTelemetry::SemanticConventions::Resource::DEPLOYMENT_ENVIRONMENT => environment,
      'telemetry.sdk.language' => 'ruby',
      'telemetry.sdk.name' => 'opentelemetry'
    )

    # OTLP exporter configuration for Honeycomb
    honeycomb_headers = {
      'x-honeycomb-team' => ENV.fetch('HONEYCOMB_API_KEY', ''),
      'x-honeycomb-dataset' => ENV.fetch('HONEYCOMB_DATASET', 'postfacto')
    }

    c.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new(
          endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', 'https://api.honeycomb.io'),
          headers: honeycomb_headers,
          compression: 'gzip',
          timeout: 30
        ),
        exporter_timeout: 30_000,
        schedule_delay: 5_000,
        max_queue_size: 2048,
        max_export_batch_size: 512
      )
    )

    # Sampling configuration - parent-based with trace ID ratio
    sampler_type = ENV.fetch('OTEL_TRACES_SAMPLER', 'parentbased_traceidratio')
    sample_ratio = ENV.fetch('OTEL_TRACES_SAMPLER_ARG', '0.1').to_f

    c.sampler = case sampler_type
                when 'always_on'
                  OpenTelemetry::SDK::Trace::Samplers::ALWAYS_ON
                when 'always_off'
                  OpenTelemetry::SDK::Trace::Samplers::ALWAYS_OFF
                when 'traceidratio'
                  OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBased.new(sample_ratio)
                when 'parentbased_traceidratio'
                  OpenTelemetry::SDK::Trace::Samplers::ParentBased.new(
                    root: OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBased.new(sample_ratio)
                  )
                else
                  OpenTelemetry::SDK::Trace::Samplers::ParentBased.new(
                    root: OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBased.new(0.1)
                  )
                end

    # Auto-instrumentation for Rails ecosystem
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
                  "sampling=#{ENV.fetch('OTEL_TRACES_SAMPLER_ARG', '0.1')}"

# Initialize metrics collector after Rails finishes loading
# Rails.application.config.after_initialize do
#   if ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true'
#     TelemetryMetricsCollector.initialize_metrics
#   end
# end
