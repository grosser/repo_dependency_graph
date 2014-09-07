require "spec_helper"
require "repo_dependency_graph/output"

describe RepoDependencyGraph::Output do
  context ".draw" do
    it "draws" do
      Dir.mktmpdir do
        Dir.chdir do
          RepoDependencyGraph::Output.send(:draw, {"foo" => [["bar"]]}, {})
          File.exist?("out.png").should == true
        end
      end
    end
  end

  context ".color" do
    it "calculates for 1 to max" do
      values = [1,2,25,50,51]
      values.map do |k,v|
        [k, RepoDependencyGraph::Output.send(:color, k, values.min..values.max)]
      end.should == [[1, "#80f31f"], [2, "#89ef19"], [25, "#fd363f"], [50, "#492efa"], [51, "#3f36fd"]]
    end
  end
end
