require "repo_dependency_graph/version"
require "organization_audit/repo"

require "bundler" # get all dependency for lockfile_parser
require "bundler/lockfile_parser"

module RepoDependencyGraph
  class << self
    def dependencies(options)
      if options[:map] && options[:external]
        raise ArgumentError, "Map only makes sense when searching for internal repos"
      end

      all = OrganizationAudit::Repo.all(options.slice(:user, :organization, :token, :max_pages)).sort_by(&:name)
      all.select!(&:private?) if options[:private]
      all.select! { |r| r.name =~ options[:select] } if options[:select]
      all.reject! { |r| r.name =~ options[:reject] } if options[:reject]

      possible = all.map(&:name)
      possible.map! { |p| p.sub(options[:map][0], options[:map][1].to_s) } if options[:map]

      dependencies = all.map do |repo|
        found = dependent_repos(repo, options)
        found.select! { |f| possible.include?(f.first) } unless options[:external]
        next if found.empty?
        puts "#{repo.name}: #{found.map { |n,v| "#{n}: #{v}" }.join(", ")}"
        [repo.name, found]
      end.compact
      Hash[dependencies]
    end

    private

    def dependent_repos(repo, options)
      repos = []

      if !options[:only] || options[:only] == "chef"
        if content = repo.content("metadata.rb")
          repos.concat scan_chef_metadata(repo.name, content)
        end
      end

      if !options[:only] || options[:only] == "gem"
        gems =
          if repo.gem?
            scan_gemspec(repo.name, repo.gemspec_content)
          elsif content = content_from_any(repo, ["gems.locked", "Gemfile.lock"])
            scan_gemfile_lock(repo.name, content)
          elsif content = content_from_any(repo, ["gems.rb", "Gemfile"])
            scan_gemfile(repo.name, content)
          end
        repos.concat gems if gems
      end

      repos
    end

    def content_from_any(repo, files)
      (file = (repo.file_list & files).first) && repo.content(file)
    end

    def scan_chef_metadata(_, content)
      content.scan(/^\s*depends ['"](.*?)['"](?:,\s?['"](.*?)['"])?/).map(&:compact)
    end

    def scan_gemfile(_, content)
      content.scan(/^\s*gem ['"](.*?)['"](?:,\s?['"](.*?)['"]|.*\bref(?::|\s*=>)\s*['"](.*)['"])?/).map(&:compact)
    end

    def scan_gemfile_lock(repo_name, content)
      content = content.gsub(/BUNDLED WITH\n.*\n/, "")
      Bundler::LockfileParser.new(content).specs.map { |d| [d.name, d.version.to_s] }
    rescue
      $stderr.puts "Error parsing #{repo_name} Gemfile.lock:\n#{content}\n\n#{$!}"
      nil
    end

    def scan_gemspec(_, content)
      content.scan(/add(?:_runtime)?_dependency[\s(]+['"]([^'"]*)['"](?:,\s*['"]([^'"]*)['"])*/).map(&:compact)
    end
  end
end
