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

      categories = []
      times_per_job.each_pair do |job, times|
        times.each do |ruby, _|
          categories << ruby unless categories.include? ruby
        end
      end

      series = times_per_job.map { |job, times|
        times = Hash[times].tap { |h| h.default = 0.0 }
        { name: job, data: times.values_at(*categories) }
      }

      title = session.name
      categories.map! { |ruby| Formatter.short_ruby_description(ruby) }

      require 'erb'
      puts ERB.new((Path.dir/'highcharts'/'barplot.html.erb').read).result(binding)
    end
  end
end

