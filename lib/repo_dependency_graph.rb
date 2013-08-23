require "repo_dependency_graph/version"
require "bundler/organization_audit/repo"
require "bundler" # get all dependency for lockfile_parser

module RepoDependencyGraph
  class << self
    MAX_HEX = 255

    def run(argv)
      draw(dependencies(parse_options(argv)))
      0
    end

    private

    def parse_options(argv)
      options = {
        :user => git_config("github.user")
      }
      OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(/^ {10}/, "")
          Draw repo dependency graph from your organization

          Usage:
              repo-dependency-graph

          Options:
        BANNER
        opts.on("--token TOKEN", "Use token") { |token| options[:token] = token }
        opts.on("--user USER", "Use user") { |user| options[:user] = user }
        opts.on("--organization ORGANIZATION", "Use organization") { |organization| options[:organization] = organization }
        opts.on("--private", "Only show private repos") { options[:private] = true }
        opts.on("--external", "Also include external projects in graph (can get super-messy)") { options[:external] = true }
        opts.on("--map SEARCH=REPLACE", "Replace in project name to find them as internal: 'foo=bar' -> replace foo in repo names to bar") do |map|
          options[:map] = map.split("=")
          options[:map][0] = Regexp.new(options[:map][0])
          options[:map][1] = options[:map][1].to_s
        end
        opts.on("--chef", "Parse chef metadata.rb files") { options[:chef] = true }
        opts.on("--select REGEX", "Only include repos with matching names") { |regex| options[:select] = Regexp.new(regex) }
        opts.on("--reject REGEX", "Exclude repos with matching names") { |regex| options[:reject] = Regexp.new(regex) }
        opts.on("-h", "--help", "Show this.") { puts opts; exit }
        opts.on("-v", "--version", "Show Version"){ puts RepoDependencyGraph::VERSION; exit}
      end.parse!(argv)
      options
    end

    def git_config(thing)
      result = `git config #{thing}`.strip
      result.empty? ? nil : result
    end

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
        gsub(/(File|IO)\.read\(['"]VERSION.*?\)/, '"1.2.3"').
        gsub(/(File|IO)\.read\(.*?\)/, '\'  VERSION = "1.2.3"\'')
    rescue Exception
      raise "Error when parsing content:\n#{content}\n\n#{$!}"
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
