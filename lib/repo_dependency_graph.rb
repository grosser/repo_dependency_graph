require "repo_dependency_graph/version"
require "bundler/organization_audit/repo"
require "bundler" # get all dependency for lockfile_parser

module RepoDependencyGraph
  class << self
    def run(options)
      draw(dependencies(options))
      0
    end

    private

    def draw(dependencies)
      require 'graphviz'

      g = GraphViz.new(:G, :type => :digraph)

      all = (dependencies.keys + dependencies.values.flatten).uniq
      nodes = Hash[all.map { |k| [k, g.add_node(k)] }]

      dependencies.each do |project,dependencies|
        dependencies.each do |dependency|
          g.add_edge(nodes[project], nodes[dependency])
        end
      end

      g.output(:png => "out.png")
    end

    def dependencies(options)
      all = Bundler::OrganizationAudit::Repo.all(options).sort_by(&:project)
      all.select!(&:private?) if options[:private]
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
        gsub(/(File|IO)\.read\(.*?\)/, '"1.2.3"')
    end
  end
end
