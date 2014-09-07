module RepoDependencyGraph
  module Output
    MAX_HEX = 255

    class << self
      def draw(dependencies, options)
        case options[:draw]
        when "html"
          draw_js(dependencies)
        when "table"
          draw_table(dependencies)
        else
          draw_png(dependencies)
        end
      end

      private

      def draw_js(dependencies)
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
      end

      def draw_table(dependencies)
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
        tables.map! { |t| "<table>\n#{t.map { |t| "<tr>#{t.map { |t| "<td>#{t}</td>" }.join("")}</tr>" }.join("\n")}\n</table>" }

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
      end

      def draw_png(dependencies)
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
end
