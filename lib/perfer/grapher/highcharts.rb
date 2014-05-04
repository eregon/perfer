module Perfer
  class HighchartsGrapher
    def initialize
      require 'json'
      require 'erb'
    end

    def compute_unit(time_per_x)
      min_scale = 0
      time_per_x.each_pair { |x, times|
        times.each { |_,t|
          scale = Formatter.float_scale(t)
          min_scale = scale if scale < min_scale
        }
      }
      unit = Formatter::TIME_UNITS[min_scale]
      in_units = 10 ** (-min_scale)
      [unit, in_units]
    end

    def render_template(name, b)
      ERB.new((Path.dir/'highcharts'/"#{name}.html.erb").read).result(b)
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

      unit, in_units = compute_unit(times_per_job)

      series = times_per_job.map { |job, times|
        times = Hash[times].tap { |h| h.default = 0.0 }
        times = times.values_at(*categories).map { |t| (t * in_units).round(1) }
        { name: job, data: times }
      }

      title = session.name
      categories.map! { |ruby| Formatter.short_ruby_description(ruby) }

      puts render_template('barplot', binding)
    end

    def timelines(session, per = :ruby) # per is :ruby or :job
      db = session.store.db
      file = session.file.to_s
      condition = { :file => file }

      # must restrict the other dimension to one possibility
      # TODO: ability to choose which one
      if per == :ruby
        condition[:job] = db[:jobs].where(condition).order(:job).get(:job)
      else
        condition[:ruby] = db[:sessions].where(condition).order(:ruby).get(:ruby)
      end

      times_per_x = db[:mean_time_per_iter_jobs]
                  .where(condition)
                  .natural_join(:sessions)
                  .order(per, :run_time)
                  .to_hash_groups(per, [:run_time, :s_per_iter])

      unit, in_units = compute_unit(times_per_x)

      series = times_per_x.map { |key,times|
        times.map! { |run_time,t| [run_time.strftime('%Q').to_i, (t * in_units).round(1)] }
        name = (per == :ruby) ? Formatter.short_ruby_description(key) : key
        { name: name, data: times }
      }

      title = if per == :ruby
        "#{session.name}##{condition[:job]} across Ruby implementations"
      else
        "#{session.name} on #{Formatter.short_ruby_description(condition[:ruby])}"
      end

      puts render_template('timelines', binding)
    end
  end
end

