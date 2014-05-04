module Perfer
  class HighchartsGrapher
    def initialize
      require 'json'
    end

    def barplot(session)
      db = session.store.db
      file = session.file.to_s

      times_per_job = db[:last_sessions_per_ruby]
                    .natural_join(:mean_time_per_iter_jobs)
                    .where(:file => file)
                    .order(:job, :ruby)
                    .to_hash_groups(:job, [:ruby, :s_per_iter])

      categories = []
      times_per_job.each_pair do |job, times|
        times.each do |ruby, _|
          categories << ruby unless categories.include? ruby
        end
      end

      min_scale = times_per_job.inject(0) { |min, (_, times)|
        [min, times.map { |_,t| Formatter.float_scale(t) }.min].min
      }
      in_units = 10 ** (-min_scale)

      series = times_per_job.map { |job, times|
        times = Hash[times].tap { |h| h.default = 0.0 }
        times = times.values_at(*categories).map { |t| (t * in_units).round(1) }
        { name: job, data: times }
      }

      title = session.name
      unit = Formatter::TIME_UNITS[min_scale]
      categories.map! { |ruby| Formatter.short_ruby_description(ruby) }

      require 'erb'
      puts ERB.new((Path.dir/'highcharts'/'barplot.html.erb').read).result(binding)
    end
  end
end

