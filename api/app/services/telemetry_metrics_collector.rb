# frozen_string_literal: true

# Service to collect business metrics for OpenTelemetry
class TelemetryMetricsCollector
  class << self
    attr_reader :meter

    def initialize_metrics
      return unless instrumentation_enabled?

      @meter = OpenTelemetry.meter_provider.meter('postfacto.metrics')

      # Gauge: Active retros in last 24 hours
      @active_retros_gauge = @meter.create_observable_gauge(
        'retro.active_count',
        unit: 'retros',
        description: 'Number of retros with activity in the last 24 hours'
      )

      # Histogram: Items per retro by category
      @items_per_retro_histogram = @meter.create_histogram(
        'retro.items_count',
        unit: 'items',
        description: 'Distribution of items per retro by category'
      )

      # Counter: Total votes by category
      @votes_counter = @meter.create_counter(
        'item.votes_total',
        unit: 'votes',
        description: 'Total number of votes on items by category'
      )

      # Histogram: Broadcast latency
      @broadcast_duration_histogram = @meter.create_histogram(
        'broadcast.duration',
        unit: 'ms',
        description: 'Duration of broadcast operations'
      )

      # Gauge: Active WebSocket connections
      @websocket_connections_gauge = @meter.create_observable_gauge(
        'websocket.connections_active',
        unit: 'connections',
        description: 'Number of active WebSocket connections'
      )

      # Register callbacks for observable metrics
      register_callbacks

      Rails.logger.info 'TelemetryMetricsCollector initialized'
    end

    def record_vote(item)
      return unless instrumentation_enabled?

      @votes_counter&.add(1, attributes: {
                            'item.category' => item.category,
                            'retro.id' => item.retro_id
                          })
    end

    def record_broadcast_duration(duration_ms, retro_id)
      return unless instrumentation_enabled?

      @broadcast_duration_histogram&.record(duration_ms, attributes: {
                                              'retro.id' => retro_id
                                            })
    end

    def record_items_per_retro(retro)
      return unless instrumentation_enabled?

      %w[happy meh sad].each do |category|
        count = retro.items.where(category: category, archived: false).count
        @items_per_retro_histogram&.record(count, attributes: {
                                             'retro.id' => retro.id,
                                             'item.category' => category
                                           })
      end
    end

    private

    def instrumentation_enabled?
      ENV.fetch('OTEL_INSTRUMENTATION_ACTIVE', 'false') == 'true' &&
        defined?(OpenTelemetry)
    end

    def register_callbacks
      # Callback for active retros count
      @meter.register_callback(
        [@active_retros_gauge],
        lambda { |result|
          count = count_active_retros
          result.observe(@active_retros_gauge, count)
        }
      )

      # Callback for active WebSocket connections
      @meter.register_callback(
        [@websocket_connections_gauge],
        lambda { |result|
          count = count_websocket_connections
          result.observe(@websocket_connections_gauge, count)
        }
      )
    end

    def count_active_retros
      # Count retros with activity (updated items/action items) in the last 24 hours
      Item.where('updated_at > ?', 24.hours.ago)
          .distinct
          .pluck(:retro_id)
          .compact
          .count
    rescue StandardError => e
      Rails.logger.warn "Failed to count active retros: #{e.message}"
      0
    end

    def count_websocket_connections
      # Count active ActionCable connections
      ActionCable.server.connections.count
    rescue StandardError => e
      Rails.logger.warn "Failed to count WebSocket connections: #{e.message}"
      0
    end
  end
end
