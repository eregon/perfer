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
        #db = Sequel.postgres('perfer')
        # Fix Alf bug https://github.com/alf-tool/alf-core/issues/7
        Sequel.datetime_class = DateTime
        setup_db(db)
        db
      end
    end

    def db
      Store.db
    end

    def load_with_alf
      require 'alf-sequel'
      file = @file
      mattrs = [:measurement_nb, :real, :utime, :stime]
      results = Alf.query(db) {
        sessions = sessions().to_relvar.restrict(file: file)
        jobs = jobs().to_relvar
        measurements = measurements().to_relvar
        (sessions * jobs * measurements).group(mattrs, :measurements)
      }

      results.to_a([:file, :run_time]).map { |result|
        metadata = result.to_hash
        measurements = metadata.delete(:measurements).to_a
        measurements.each { |m| m.delete :measurement_nb }
        Result.new(metadata, measurements)
      }
    end

    def load
      return YAMLStore.new(@file).load if ENV['PERFER_LOAD_FROM_YAML']

      m_key = lambda { |m| m.values_at(:file, :run_time, :job) }

      measurements = db[:measurements].where(file: @file).to_a.group_by(&m_key)
      measurements.each_value do |ms|
        ms.map! { |m|
          { real: m[:real], utime: m[:utime], stime: m[:stime] }
        }
      end

      db[:sessions].where(file: @file)
                   .natural_join(db[:jobs])
                   .order(:file, :run_time).map { |metadata|
        data = measurements[m_key.call(metadata)]
        Result.new(metadata, data)
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
                         job: r[:job].to_s, iterations: r[:iterations])
        r.each.with_index(1) do |m, i|
          db[:measurements].insert(
            file: @file, run_time: r[:run_time], job: r[:job].to_s,
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

  class YAMLStore
    def initialize(bench_file)
      @file = YAMLStore.path_for_bench_file(bench_file)
    end

    def self.results_dir
      DIR/'results'
    end

    def self.path_for_bench_file(bench_file)
      path = results_dir
      path.mkpath unless path.exist?

      bench_file = Path(bench_file)
      return bench_file if bench_file.inside?(results_dir)

      # get the relative path to root, and relocate in @path
      names = bench_file.each_filename.to_a
      # prepend drive letter on Windows
      names.unshift bench_file.path[0..0].upcase if File.dirname('C:') == 'C:.'

      path.join(*names).add_ext('.yml')
    end

    def yaml_load_documents
      docs = @file.open { |f| YAML.load_stream(f) }
      docs = docs.documents unless Array === docs
      docs
    end

    def load
      return [] unless @file.exist?
      yaml_load_documents.map { |doc|
        doc = doc.to_hash if Result === doc
        metadata = doc[:metadata]
        metadata.delete(:command_line) # not supported at the moment
        metadata.delete(:verbose) # legacy
        Result.new(metadata, doc[:data])
      }
    end
  end
end
