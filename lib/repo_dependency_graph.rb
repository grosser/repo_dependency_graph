require "repo_dependency_graph/version"
require "organization_audit/repo"
require "bundler" # get all dependency for lockfile_parser

module RepoDependencyGraph
  class << self
    MAX_HEX = 255

    def run(argv)
      options = parse_options(argv)
      draw(dependencies(options), options)
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
        opts.on("--draw TYPE", "png, html, table (default: png)") { |draw| options[:draw] = draw }
        opts.on("--organization ORGANIZATION", "Use organization") { |organization| options[:organization] = organization }
        opts.on("--private", "Only show private repos") { options[:private] = true }
        opts.on("--external", "Also include external projects in graph (can get super-messy)") { options[:external] = true }
        opts.on("--map SEARCH=REPLACE", "Replace in project name to find them as internal: 'foo=bar' -> replace foo in repo names to bar") do |map|
          options[:map] = map.split("=")
          options[:map][0] = Regexp.new(options[:map][0])
          options[:map][1] = options[:map][1].to_s
        end
        opts.on("--only TYPE", String, "Only this type (chef,gem), default: all") { |t| options[:only] = t }
        opts.on("--select REGEX", "Only include repos with matching names") { |regex| options[:select] = Regexp.new(regex) }
        opts.on("--reject REGEX", "Exclude repos with matching names") { |regex| options[:reject] = Regexp.new(regex) }
        opts.on("-h", "--help", "Show this.") { puts opts; exit }
        opts.on("-v", "--version", "Show Version"){ puts RepoDependencyGraph::VERSION; exit}
      end.parse!(argv)

      options[:token] ||= begin
        token = `git config github.token`.strip
        token if $?.success?
      end

      options
    end

    def git_config(thing)
      result = `git config #{thing}`.strip
      result.empty? ? nil : result
    end

    def draw(dependencies, options)
      case options[:draw]
      when "html"
        nodes, edges = convert_to_graphviz(dependencies)
        html = <<-HTML.gsub(/^          /, "")
          <!doctype html>
          <html>
            <head>
              <title>Network</title>
            <style>
              #mynetwork {
                width: 2000px;
                height: 2000px;
                border: 1px solid lightgray;
                background: #F3F3F3;
              }
            </style>

            <script type="text/javascript" src="http://visjs.org/dist/vis.js"></script>
            <link href="http://visjs.org/dist/vis.css" rel="stylesheet" type="text/css" />

            <script type="text/javascript">
              var nodes = null;
              var edges = null;
              var network = null;

              function draw() {
                nodes = #{nodes.values.to_json};
                edges = #{edges.to_json};

                var container = document.getElementById('mynetwork');
                var data = {
                  nodes: nodes,
                  edges: edges
                };
                var options = {stabilize: false};

                new vis.Network(container, data, options);
              }
            </script>
          </head>

          <body onload="draw()">
            <div id="mynetwork"></div>
          </body>
        </html>
        HTML
        File.write("out.html", html)
      when "table"
        tables = dependencies.map do |name, uses|
          used = dependencies.map do |d, uses|
            used = uses.detect { |d| d.first == name }
            [d, used.last] if used
          end.compact
          size = [used.size, uses.size, 1].max
          table = []
          size.times do |i|
            table[i] = [
              (used[i] || []).join(": "),
              (name if i == 0),
              (uses[i] || []).join(": ")
            ]
          end
          table.unshift ["Used", "", "Uses"]
          table
        end
        tables.map!{ |t| "<table>\n#{t.map{|t| "<tr>#{t.map{|t| "<td>#{t}</td>" }.join("")}</tr>"  }.join("\n")}\n</table>" }

        html = <<-HTML.gsub(/^          /, "")
          <!doctype html>
          <html>
            <head>
              <title>Network</title>
              <style>
                table { width: 600px; }
              </style>
            </head>
            <body>
              #{tables.join("<br>\n<br>\n")}
            </body>
          </html>
        HTML
        File.write("out.html", html)
      else
        nodes, edges = convert_to_graphviz(dependencies)
        require 'graphviz'
        g = GraphViz.new(:G, :type => :digraph)

        nodes = Hash[nodes.map do |_, data|
          node = g.add_node(data[:id], :color => data[:color], :style => "filled")
          [data[:id], node]
        end]

        edges.each do |edge|
          g.add_edge(nodes[edge[:from]], nodes[edge[:to]], :label => edge[:label])
        end

        g.output(:png => "out.png")
      end
    end

    def convert_to_graphviz(dependencies)
      counts = dependency_counts(dependencies)
      range = counts.values.min..counts.values.max
      nodes = Hash[counts.each_with_index.map do |(name, count), i|
        [name, {:id => name, :color => color(count, range)}]
      end]
      edges = dependencies.map do |name, dependencies|
        dependencies.map do |dependency, version|
          {:from => nodes[name][:id], :to => nodes[dependency][:id], :label => (version || '')}
        end
      end.flatten
      [nodes, edges]
    end

    def dependencies(options)
      if options[:map] && options[:external]
        raise ArgumentError, "Map only makes sense when searching for internal repos"
      end

      all = OrganizationAudit::Repo.all(options).sort_by(&:name)
      all = all.select(&:private?) if options[:private]
      all = all.select { |r| r.name =~ options[:select] } if options[:select]
      all = all.reject { |r| r.name =~ options[:reject] } if options[:reject]

      possible = all.map(&:name)
      possible.map! { |p| p.sub(options[:map][0], options[:map][1].to_s) } if options[:map]

      dependencies = all.map do |repo|
        found = dependent_repos(repo, options) || []
        found.select! { |f| possible.include?(f.first) } unless options[:external]
        next if found.empty?
        puts "#{repo.name}: #{found.map { |n,v| "#{n}: #{v}" }.join(", ")}"
        [repo.name, found]
      end.compact
      Hash[dependencies]
    end

    def dependent_repos(repo, options)
      repos = []

      if !options[:only] || options[:only] == "chef"
        if content = repo.content("metadata.rb")
          repos.concat scan_chef_metadata(content)
        end
      end

      if !options[:only] || options[:only] == "gem"
        gems = if repo.gem? && spec = load_spec(repo.gemspec_content)
          spec.runtime_dependencies.map do |d|
            r = d.requirement.to_s
            r = nil if r == ">= 0"
            [d.name, r].compact
          end
        elsif content = repo.content("Gemfile.lock")
          scan_gemfile_lock(content)
        elsif content = repo.content("Gemfile")
          scan_gemfile(content)
        end
        repos.concat gems
      end

      repos
    end

    def scan_chef_metadata(content)
      content.scan(/^\s*depends ['"](.*?)['"](?:,\s?['"](.*?)['"])?/).map(&:compact)
    end

    def scan_gemfile(content)
      content.scan(/^\s*gem ['"](.*?)['"](?:,\s?['"](.*?)['"]|.*\bref(?::|\s*=>)\s*['"](.*)['"])?/).map(&:compact)
    end

    def scan_gemfile_lock(content)
      Bundler::LockfileParser.new(content).specs.map { |d| [d.name, d.version.to_s] }
    end

    def load_spec(content)
      eval content.
        gsub(/^\s*require .*$/, "").
        gsub(/([a-z\d]+::)+version(::[a-z]+)?/i){|x| x =~ /^Gem::Version$/i ? x : '"1.2.3"' }.
        gsub(/^\s*\$(:|LOAD_PATH).*/, "").
        gsub(/(File|IO)\.read\(['"]VERSION.*?\)/, '"1.2.3"').
        gsub(/(File|IO)\.read\(.*?\)/, '\'  VERSION = "1.2.3"\'')
    rescue Exception
      $stderr.puts "Error when parsing content:\n#{content}\n\n#{$!}"
      nil
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
      all = (dependencies.keys + dependencies.values.map { |v| v.map(&:first) }).flatten.uniq
      Hash[all.map do |k|
        [k, dependencies.values.map(&:first).count { |name, _| name ==  k } ]
      end]
    end
  end
end
