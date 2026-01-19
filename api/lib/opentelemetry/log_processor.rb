# frozen_string_literal: true

module OpenTelemetry
  # Log processor to inject trace context into log messages
  class LogProcessor < Logger::Formatter
    def initialize(original_formatter = nil)
      super()
      @original_formatter = original_formatter || Logger::Formatter.new
    end

    def call(severity, time, progname, msg)
      # Get current span context
      current_span = OpenTelemetry::Trace.current_span
      span_context = current_span.context if current_span

      # Build trace context attributes
      trace_context = if span_context&.valid?
                        {
                          trace_id: span_context.hex_trace_id,
                          span_id: span_context.hex_span_id,
                          trace_flags: span_context.trace_flags.sampled? ? '01' : '00'
                        }
                      else
                        {}
                      end

      # Format the message with trace context
      formatted_msg = if trace_context.any?
                        "[trace_id=#{trace_context[:trace_id]} span_id=#{trace_context[:span_id]}] #{msg}"
                      else
                        msg
                      end

      # Use original formatter if available
      @original_formatter.call(severity, time, progname, formatted_msg)
    end
  end
end
