require "repo_dependency_graph/version"
require "bundler/organization_audit/repo"
require "bundler" # get all dependency for lockfile_parser

module RepoDependencyGraph
  class << self
    MAX_HEX = 255

    def run(options)
      draw(dependencies(options))
      0
    end

    private

    def draw(dependencies)
      require 'graphviz'

      g = GraphViz.new(:G, :type => :digraph)

      counts = dependency_counts(dependencies)
      range = counts.values.min..counts.values.max

      nodes = Hash[counts.map do |project, count|
        node = g.add_node(project, :color => color(count, range), :style => "filled")
        [project, node]
      end]

      dependencies.each do |project, dependencies|
        dependencies.each do |dependency|
          g.add_edge(nodes[project], nodes[dependency])
        end
      end

      g.output(:png => "out.png")
    end

    def dependencies(options)
      if options[:map] && options[:external]
        raise ArgumentError, "Map only makes sense when searching for internal repos"
      end

      all = Bundler::OrganizationAudit::Repo.all(options).sort_by(&:project)
      all = all.select(&:private?) if options[:private]
      all = all.select { |r| r.project =~ options[:select] } if options[:select]
      all = all.reject { |r| r.project =~ options[:reject] } if options[:reject]

      possible = all.map(&:project)
      possible.map! { |p| p.sub(options[:map][0], options[:map][1].to_s) } if options[:map]

      dependencies = all.map do |repo|
        found = dependent_repos(repo, options) || []
        found = found & possible unless options[:external]
        next if found.empty?
        puts "#{repo.project}: #{found.join(", ")}"
        [repo.project, found]
      end.compact
      Hash[dependencies]
    end

    def dependent_repos(repo, options)
      if options[:chef]
        if content = repo.content("metadata.rb")
          content.scan(/^\s*depends ['"](.*?)['"]/).flatten
        end
      else
        if repo.gem?
          load_spec(repo.gemspec_content).runtime_dependencies.map(&:name)
        elsif content = repo.content("Gemfile.lock")
          Bundler::LockfileParser.new(content).specs.map(&:name)
        elsif content = repo.content("Gemfile")
          content.scan(/^\s*gem ['"](.*?)['"]/).flatten
        end
      end
    end

    def load_spec(content)
      eval content.
        gsub(/^\s*require .*$/, "").
        gsub(/([a-z\d]+::)+version/i, '"1.2.3"').
        gsub(/^\s*\$(:|LOAD_PATH).*/, "").
        gsub(/(File|IO)\.read\(.*?\)/, '"1.2.3"')
    end

    def color(value, range)
      value -= range.min # lowest -> green
      max = range.max - range.min

      i = (value * MAX_HEX / max);
      i *= 0.6 # green-blue gradient instead of green-green
      half = MAX_HEX * 0.5
      values = [0,2,4].map { |v| (Math.sin(0.024 * i + v) * half + half).round.to_s(16).rjust(2, "0") }
      "##{values.join}"
    end

    def dependency_counts(dependencies)
      all = (dependencies.keys + dependencies.values.flatten).uniq
      Hash[all.map do |k|
        [k, dependencies.values.count { |v| v.include?(k) } ]
      end]
    end
  end
end
