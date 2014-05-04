module Perfer
  class HighchartsGrapher
    def initialize
      require 'json'
    end

    def barplot(session)
      db = session.store.db
      file = session.file

      times_per_job = db[:last_sessions_per_ruby]
                    .natural_join(:mean_time_per_iter_jobs)
                    .where(:file => file.to_s)
                    .order(:job, :ruby)
                    .to_hash_groups(:job, [:ruby, :s_per_iter])

      categories = {}
      times_per_job.each_pair do |job, times|
        times.each do |ruby, s_per_iter|
          unless categories.key? ruby
            categories[ruby] = categories.size
          end
        end
      end

      series = []
      times_per_job.each_pair { |job, times|
        d = categories.map { 0.0 }
        times.each { |ruby, s_per_iter|
          d[categories[ruby]] = s_per_iter
        }
        series << { name: job, data: d }
      }

      title = session.name
      categories = categories.keys.map { |ruby| Formatter.short_ruby_description(ruby) }

      require 'erb'
      puts ERB.new((Path.dir/'highcharts'/'barplot.html.erb').read).result(binding)
    end
  end
end

