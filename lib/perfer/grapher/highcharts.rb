module Perfer
  class HighchartsGrapher
    def initialize
      require 'json'
      require 'erb'
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

      puts ERB.new((Path.dir/'highcharts'/'barplot.html.erb').read).result(binding)
    end

    def timelines(session)
      db = session.store.db
      file = session.file.to_s

      # must restrict to one job!
      job = db[:jobs].where(:file => file).order(:job).get(:job) # TODO

      times_per_ruby = db[:mean_time_per_iter_jobs]
                     .where(:file => file, :job => job)
                     .natural_join(:sessions)
                     .order(:ruby, :run_time)
                     .to_hash_groups(:ruby, [:run_time, :s_per_iter])

      min_scale = times_per_ruby.inject(0) { |min, (_, times)|
        [min, times.map { |_,t| Formatter.float_scale(t) }.min].min
      }
      in_units = 10 ** (-min_scale)

      series = times_per_ruby.map { |ruby,times|
        d = times.map { |run_time,t| [run_time.strftime('%Q').to_i, (t * in_units).round(1)] }
        { name: Formatter.short_ruby_description(ruby), data: d }
      }
      title = session.name
      unit = Formatter::TIME_UNITS[min_scale]

      puts ERB.new((Path.dir/'highcharts'/'timelines.html.erb').read).result(binding)
    end
  end
end

