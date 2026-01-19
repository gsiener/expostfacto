# frozen_string_literal: true

# Concern for instrumenting ActiveRecord models with OpenTelemetry
module OpentelemetryInstrumentedModel
  extend ActiveSupport::Concern

  included do
    after_commit :otel_record_model_event, on: [:create]
    after_commit :otel_record_model_update, on: [:update]
    after_commit :otel_record_model_destroy, on: [:destroy]
  end

  private

  def otel_record_model_event
    return unless instrumentation_enabled?

    tracer = OpenTelemetry.tracer_provider.tracer('postfacto.models')
    tracer.in_span("#{model_name.element}_created") do |span|
      add_base_attributes(span, 'create')
      add_model_attributes(span) if respond_to?(:add_model_attributes, true)
      span.status = OpenTelemetry::Trace::Status.ok
    end
  end

  def otel_record_model_update
    return unless instrumentation_enabled?

    tracer = OpenTelemetry.tracer_provider.tracer('postfacto.models')
    tracer.in_span("#{model_name.element}_updated") do |span|
      add_base_attributes(span, 'update')
      add_model_attributes(span) if respond_to?(:add_model_attributes, true)

      # Include what changed
      if previous_changes.present?
        changed_attrs = previous_changes.keys.join(', ')
        span.set_attribute('db.changed_attributes', changed_attrs)
      end

      span.status = OpenTelemetry::Trace::Status.ok
    end
  end

  def otel_record_model_destroy
    return unless instrumentation_enabled?

    tracer = OpenTelemetry.tracer_provider.tracer('postfacto.models')
    tracer.in_span("#{model_name.element}_destroyed") do |span|
      add_base_attributes(span, 'destroy')
      add_model_attributes(span) if respond_to?(:add_model_attributes, true)
      span.status = OpenTelemetry::Trace::Status.ok
    end
  end

  def add_base_attributes(span, operation)
    span.set_attribute('db.system', 'postgresql')
    span.set_attribute('db.table', self.class.table_name)
    span.set_attribute('db.operation', operation)
    span.set_attribute('db.record_id', id) if id.present?
  end

  def instrumentation_enabled?
    ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true' &&
      defined?(OpenTelemetry)
  end
end
