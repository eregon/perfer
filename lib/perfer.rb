require 'epath'

module Perfer
  @sessions = []

  class << self
    attr_reader :sessions

    def session(name, &block)
      Session.new(name, Path.file(caller), &block).tap { |session|
        @sessions << session
      }
    end

    def measure(result = {})
      times_before = Process.times
      realtime_before = Time.now
      yield
      times = Process.times
      realtime = Time.now

      result[:real] = realtime-realtime_before
      times.members.each { |field|
        # precision of times(3) or getrusage(2) is no more than 1e-6
        result[field.to_sym] = (times[field] - times_before[field]).round(6)
      }
      result
    end
  end
end

Path.require_tree('perfer', :except => %w[platform/])
