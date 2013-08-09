require "spec_helper"

describe RepoDependencyGraph do
  it "has a VERSION" do
    RepoDependencyGraph::VERSION.should =~ /^[\.\da-z]+$/
  end

  context "CLI" do
    it "shows --version" do
      audit("--version").should include(RepoDependencyGraph::VERSION)
    end

    it "shows --help" do
      audit("--help").should include("Draw repo dependency graph from your organization")
    end

    def audit(command, options={})
      sh("bin/repo-dependency-graph #{command}", options)
    end

    def sh(command, options={})
      result = `#{command} #{"2>&1" unless options[:keep_output]}`
      raise "FAILED #{command}\n#{result}" if $?.success? == !!options[:fail]
      result
    end
  end
end
