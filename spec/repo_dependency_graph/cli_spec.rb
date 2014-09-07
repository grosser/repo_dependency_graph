require "spec_helper"
require "repo_dependency_graph/cli"

describe RepoDependencyGraph::CLI do
  def audit(command, options={})
    sh("bin/repo-dependency-graph #{command}", options)
  end

  def sh(command, options={})
    result = `#{command} #{"2>&1" unless options[:keep_output]}`
    raise "FAILED #{command}\n#{result}" if $?.success? == !!options[:fail]
    result
  end

  it "shows --version" do
    audit("--version").should include(RepoDependencyGraph::VERSION)
  end

  it "shows --help" do
    audit("--help").should include("Draw repo dependency graph from your organization")
  end

  context ".parse_options" do
    def call(argv, keep=[])
      result = RepoDependencyGraph::CLI.send(:parse_options, argv)
      result.delete(:user) unless keep == :user
      result.delete(:token) unless keep == :token
      result
    end

    it "uses current user by default" do
      result = call([], :user)
      result.keys.should == [:user]
    end

    it "parses --user" do
      call(["--user", "foo"], :user).should == {:user => "foo"}
    end

    it "parses --organization" do
      call(["--organization", "foo"]).should == {:organization => "foo"}
    end

    it "parses --token" do
      call(["--token", "foo"], :token).should == {:token => "foo"}
    end

    it "parses --private" do
      call(["--private"]).should == {:private => true}
    end

    it "parses --external" do
      call(["--external"]).should == {:external => true}
    end

    it "parses --only" do
      call(["--only", "chef"]).should == {:only => "chef"}
    end

    it "parses simple --map" do
      call(["--map", "A=B"]).should == {:map => [/A/, "B"]}
    end

    it "parses empty --map" do
      call(["--map", "A="]).should == {:map => [/A/, ""]}
    end

    it "parses regex --map" do
      call(["--map", "A.?=B"]).should == {:map => [/A.?/, "B"]}
    end

    it "parses --select" do
      call(["--select", "A.?B"]).should == {:select => /A.?B/}
    end

    it "parses --reject" do
      call(["--reject", "A.?B"]).should == {:reject => /A.?B/}
    end
  end
end
