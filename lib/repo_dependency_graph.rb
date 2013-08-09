require "repo_dependency_graph/version"
require "bundler/organization_audit/repo"
require "bundler" # get all dependency for lockfile_parser

module RepoDependencyGraph
  class Repo < Bundler::OrganizationAudit::Repo
    def content(file)
      @content ||= {}
      @content[file] ||= super
    end

    def gem?
      !!gemspec_content
    end

    def gemspec_content
      content("#{project}.gemspec")
    end
  end

  class << self
    def run(options)
      puts dependencies(options)
      0
    end

    private

    def dependencies(options)
      all = Repo.all(options).select(&:private?).sort_by(&:project)
      possible = all.map(&:project)
      dependencies = all.map do |repo|
        found = dependent_gems(repo) || []
        found = found & possible
        next if found.empty?
        puts "#{repo.project}: #{found.join(", ")}"
        [repo.project, found]
      end.compact
      Hash[dependencies]
    end

    def dependent_gems(repo)
      if repo.gem?
        load_spec(repo.gemspec_content).runtime_dependencies.map(&:name)
      elsif content = repo.content("Gemfile.lock")
        Bundler::LockfileParser.new(content).specs.map(&:name)
      elsif content = repo.content("Gemfile")
        content.scan(/gem ['"](.*?)['"]/).flatten
      end
    end

    def load_spec(content)
      eval content.
        gsub(/^\s*require .*$/, "").
        gsub(/([a-z\d]+::)+version/i, '"1.2.3"').
        gsub(/^\s*\$(:|LOAD_PATH).*/, "").
        gsub(/File\.read\(.*?\)/, '"1.2.3"')
    end
  end
end
