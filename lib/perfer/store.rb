module Perfer
  class Store
    attr_reader :file
    def initialize(file)
      @file = Path(file).to_s
    end

    def self.for_session(session)
      new session.file
    end

    def self.db
      @db ||= begin
        require 'sequel'
        Sequel.sqlite((Perfer::DIR/'perfer.db').path)
      end
    end

    def db
      Store.db
    end

    def load
      setup_db

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

    def add(results)
      return if results.empty?

      m = results.first.metadata.dup
      # remove job-related attributes
      m.delete(:job)
      m.delete(:iterations)

      db[:sessions].insert(m)

      results.each do |r|
        m[:jobs].insert(file: @file, run_time: r[:run_time],
                        job: r[:job], iterations: r[:iterations])
        r.each.with_index(1) do |m, i|
          m[:measurements].insert(
            file: @file, run_time: r[:run_time], job: r[:job],
            measurement_nb: i, realtime: m[:real], utime: m[:utime], stime: m[:stime])
        end
      end
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
      tables = [:sessions, :jobs, :measurements]
      return if (db.tables & tables) == tables
      # create the sessions table
      db.create_table :sessions do
        String :file
        Time :run_time
        String :session
        Float :minimal_time
        Integer :measurements
        String :ruby
        String :git_branch
        String :git_commit
        String :bench_file_checksum
        primary_key [:file, :run_time]
      end

      # create the jobs table
      db.create_table :jobs do
        String :file
        Time :run_time
        String :job
        Integer :iterations
        primary_key [:file, :run_time, :job]
        foreign_key [:file, :run_time], :sessions
      end

      # create the measurements table
      db.create_table :measurements do
        String :file
        Time :run_time
        String :job
        Integer :measurement_nb
        Float :realtime
        Float :utime
        Float :stime
        primary_key [:file, :run_time, :job, :measurement_nb]
        foreign_key [:file, :run_time, :job], :jobs
      end
    end
  end
end
