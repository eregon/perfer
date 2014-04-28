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
        db = Sequel.sqlite((Perfer::DIR/'perfer.db').path)
        # Fix Alf bug https://github.com/alf-tool/alf-core/issues/7
        Sequel.datetime_class = DateTime
        setup_db(db)
        db
      end
    end

    def db
      Store.db
    end

    def load
      require 'alf'
      file = @file
      mattrs = [:measurement_nb, :real, :utime, :stime]
      results = Alf.query(db) {
        sessions = sessions().to_relvar.restrict(file: file)
        jobs = jobs().to_relvar
        measurements = measurements().to_relvar
        (sessions * jobs * measurements).group(mattrs, :measurements)
      }

      results.map { |result|
        metadata = result.to_hash
        measurements = metadata.delete(:measurements).to_a
        measurements.each { |m| m.delete :measurement_nb }
        metadata[:run_time] = metadata[:run_time].to_time
        Result.new(metadata, measurements)
      }
    end

    def add(results)
      results.each do |r|
        unless db[:sessions].first(file: @file, run_time: r[:run_time])
          m = r.metadata.dup
          # remove job-related attributes
          m.delete(:job)
          m.delete(:iterations)

          db[:sessions].insert(m)
        end

        db[:jobs].insert(file: @file, run_time: r[:run_time],
                         job: r[:job], iterations: r[:iterations])
        r.each.with_index(1) do |m, i|
          db[:measurements].insert(
            file: @file, run_time: r[:run_time], job: r[:job],
            measurement_nb: i,
            real:  m[:real]  || 0.0,
            utime: m[:utime] || 0.0,
            stime: m[:stime] || 0.0)
        end
      end
    end

    def delete
      db[:measurements].where(file: @file).delete
      db[:jobs].where(file: @file).delete
      db[:sessions].where(file: @file).delete
    end

    def save(results)
      delete
      add(results)
    end

    def rewrite
      save load
    end

    def self.setup_db(db)
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
        Float :real
        Float :utime
        Float :stime
        primary_key [:file, :run_time, :job, :measurement_nb]
        foreign_key [:file, :run_time, :job], :jobs
      end
    end
    private_class_method :setup_db
  end
end
