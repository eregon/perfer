module Perfer
  class Store
    attr_reader :file
    def initialize(file)
      @file = Path(file).to_s
    end

    def self.for_session(session)
      new session
    end

    def self.db
      @db ||= todo
    end

    def load
      setup_db
      # db[:sessions].natural_join(:jobs)
      #              .natural_join(:measurements)
      #              .where(file: @file)
      #              .to_a
      #              .group_by { |t| [t[:file], t[:run_time], t[:job]] }
      #              .map { |key, h|
      #   Result.new()
      # }
      #   Result.new(metadata, measurements)
      # }

      # file = @file
      # mattrs = @db[:measurements].columns
      # results = Alf.query(@db) {
      #   sessions = sessions().to_relvar.where(file: file)
      #   jobs = jobs().to_relvar
      #   measurements = measurements().to_relvar
      #   (sessions * jobs * measurements).group(mattrs, :measurements, allbut: true)
      # }
      # results.map { |result|
      #   p result
      #   measurements = result.delete(:measurements).to_a
      #   measurements.each { |m| m.delete :measurement_nb }
      #   Result.new(result, measurements)
      # }
    end

    def append(result)
      @file.dir.mkpath unless @file.dir.exist?
      @file.append YAML.dump(result.to_hash)
    end

    def save(results)
      @file.dir.mkpath unless @file.dir.exist?
      # ensure results are still ordered by :run_time
      unless results.each_cons(2) { |a,b| a[:run_time] <= b[:run_time] }
        results.sort_by! { |r| r[:run_time] }
      end
      @file.write YAML.dump_stream(*results.map(&:to_hash))
    end

    def rewrite
      save load
    end

  private
    def setup_db
      require 'sequel'
      # TODO
    end
  end
end
