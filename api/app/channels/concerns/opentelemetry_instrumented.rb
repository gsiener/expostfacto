# frozen_string_literal: true

# Concern for instrumenting ActionCable channels with OpenTelemetry
module OpentelemetryInstrumented
  extend ActiveSupport::Concern

  included do
    before_subscribe :otel_before_subscribe
    after_subscribe :otel_after_subscribe
    before_unsubscribe :otel_before_unsubscribe
    after_unsubscribe :otel_after_unsubscribe
  end

  private

  def otel_before_subscribe
    return unless instrumentation_enabled?

    tracer = OpenTelemetry.tracer_provider.tracer('postfacto.actioncable')
    @otel_subscribe_span = tracer.start_span(
      'actioncable.subscribe',
      kind: :consumer
    )

    # Add channel attributes
    @otel_subscribe_span.set_attribute('messaging.system', 'actioncable')
    @otel_subscribe_span.set_attribute('messaging.channel', self.class.name)
    @otel_subscribe_span.set_attribute('messaging.connection_id', connection.connection_identifier)
    @otel_subscribe_span.set_attribute('messaging.operation', 'subscribe')
  end

  def otel_after_subscribe
    return unless instrumentation_enabled? && @otel_subscribe_span

    # Add retro-specific attributes if retro_id is available
    if respond_to?(:retro_id) && retro_id.present?
      @otel_subscribe_span.set_attribute('retro.id', retro_id)

      # Get consumer count for this retro
      consumer_count = count_retro_consumers(retro_id)
      @otel_subscribe_span.set_attribute('retro.consumer_count', consumer_count)
    end

    @otel_subscribe_span.status = OpenTelemetry::Trace::Status.ok
    @otel_subscribe_span.finish
    @otel_subscribe_span = nil
  end

  def otel_before_unsubscribe
    return unless instrumentation_enabled?

    tracer = OpenTelemetry.tracer_provider.tracer('postfacto.actioncable')
    @otel_unsubscribe_span = tracer.start_span(
      'actioncable.unsubscribe',
      kind: :consumer
    )

    # Add channel attributes
    @otel_unsubscribe_span.set_attribute('messaging.system', 'actioncable')
    @otel_unsubscribe_span.set_attribute('messaging.channel', self.class.name)
    @otel_unsubscribe_span.set_attribute('messaging.connection_id', connection.connection_identifier)
    @otel_unsubscribe_span.set_attribute('messaging.operation', 'unsubscribe')

    # Add retro-specific attributes if retro_id is available
    if respond_to?(:retro_id) && retro_id.present?
      @otel_unsubscribe_span.set_attribute('retro.id', retro_id)
    end
  end

  def otel_after_unsubscribe
    return unless instrumentation_enabled? && @otel_unsubscribe_span

    @otel_unsubscribe_span.status = OpenTelemetry::Trace::Status.ok
    @otel_unsubscribe_span.finish
    @otel_unsubscribe_span = nil
  end

  def instrumentation_enabled?
    ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true' &&
      defined?(OpenTelemetry)
  end

  def count_retro_consumers(retro_id)
    # Count active subscribers to this retro channel
    # ActionCable doesn't provide a direct way to count subscribers,
    # so we estimate based on connections streaming from this channel
    ActionCable.server.connections.count { |conn|
      conn.subscriptions.identifiers.any? { |id|
        subscription = conn.subscriptions.send(:subscriptions)[id]
        subscription.is_a?(self.class) &&
          subscription.respond_to?(:retro_id) &&
          subscription.retro_id == retro_id
      }
    }
  rescue StandardError => e
    Rails.logger.warn "Failed to count retro consumers: #{e.message}"
    0
  end
end
