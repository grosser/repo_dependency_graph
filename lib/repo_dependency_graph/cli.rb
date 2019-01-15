require 'repo_dependency_graph'
require 'repo_dependency_graph/output'

module RepoDependencyGraph
  module CLI
    class << self
      def run(argv)
        options = parse_options(argv)
        RepoDependencyGraph::Output.draw(
          RepoDependencyGraph.dependencies(options), options
        )
        0
      end

      private

      def parse_options(argv)
        options = {
          :user => git_config("github.user")
        }
        OptionParser.new do |opts|
          opts.banner = <<-BANNER.gsub(/^          /, "")
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
          opts.on("--max-pages PAGES", Integer, "") { |p| options[:max_pages] = p }
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
    end
  end
end
