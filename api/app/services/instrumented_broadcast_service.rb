# frozen_string_literal: true

# Service to instrument ActionCable broadcasts with OpenTelemetry
class InstrumentedBroadcastService
  class << self
    # Broadcast a retro update with OpenTelemetry instrumentation
    def broadcast_retro_update(retro)
      return RetrosChannel.broadcast(retro) unless instrumentation_enabled?

      tracer = OpenTelemetry.tracer_provider.tracer('postfacto.broadcast')
      tracer.in_span('broadcast.retro_update', kind: :producer) do |span|
        start_time = Time.current

        # Add retro attributes
        add_retro_attributes(span, retro)

        # Serialize and measure payload
        payload = RetroSerializer.new(retro).as_json
        payload_json = payload.to_json
        span.set_attribute('payload_size_bytes', payload_json.bytesize)

        # Get consumer count
        consumer_count = RetroSessionService.instance.get_retro_consumers(retro.id).count
        span.set_attribute('retro.connected_consumers', consumer_count)

        # Perform the broadcast
        begin
          RetrosChannel.broadcast(retro)

          # Record duration
          duration_ms = ((Time.current - start_time) * 1000).round(2)
          span.set_attribute('broadcast.duration_ms', duration_ms)

          span.status = OpenTelemetry::Trace::Status.ok
        rescue StandardError => e
          span.record_exception(e)
          span.status = OpenTelemetry::Trace::Status.error("Broadcast failed: #{e.message}")
          raise
        end
      end
    end

    # Broadcast a force relogin command with instrumentation
    def broadcast_force_relogin(retro, originator_id)
      return RetrosChannel.broadcast_force_relogin(retro, originator_id) unless instrumentation_enabled?

      tracer = OpenTelemetry.tracer_provider.tracer('postfacto.broadcast')
      tracer.in_span('broadcast.force_relogin', kind: :producer) do |span|
        start_time = Time.current

        # Add retro attributes
        add_retro_attributes(span, retro)
        span.set_attribute('originator.id', originator_id)

        # Get consumer count before disconnection
        consumer_count = RetroSessionService.instance.get_retro_consumers(retro.id).count
        span.set_attribute('retro.connected_consumers', consumer_count)

        # Perform the broadcast and disconnection
        begin
          RetrosChannel.broadcast_force_relogin(retro, originator_id)

          # Record duration
          duration_ms = ((Time.current - start_time) * 1000).round(2)
          span.set_attribute('broadcast.duration_ms', duration_ms)
          span.set_attribute('consumers_disconnected', consumer_count)

          span.status = OpenTelemetry::Trace::Status.ok
        rescue StandardError => e
          span.record_exception(e)
          span.status = OpenTelemetry::Trace::Status.error("Force relogin broadcast failed: #{e.message}")
          raise
        end
      end
    end

    private

    def instrumentation_enabled?
      ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true' &&
        defined?(OpenTelemetry)
    end

    def add_retro_attributes(span, retro)
      span.set_attribute('retro.id', retro.id)
      span.set_attribute('retro.slug', retro.slug)
      span.set_attribute('retro.items_count', retro.items.count)
      span.set_attribute('retro.action_items_count', retro.action_items.count)
      span.set_attribute('retro.is_private', retro.is_private?)
    end
  end
end
