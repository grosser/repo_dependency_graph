require "spec_helper"

describe RepoDependencyGraph do
  def silence_stderr
    old, $stderr = $stderr, StringIO.new
    yield
  ensure
    $stderr = old
  end

  let(:config){ YAML.load_file("spec/private.yml") }

  it "has a VERSION" do
    RepoDependencyGraph::VERSION.should =~ /^[\.\da-z]+$/
  end

  context ".dependencies" do
    before do
      RepoDependencyGraph.stub(:puts)
    end

    if File.exist?("spec/private.yml")
      it "gathers dependencies for private organizations" do
        graph = RepoDependencyGraph.send(:dependencies,
          :organization => config["organization"],
          :token => config["token"],
          :select => Regexp.new(config["expected_organization_select"])
        )
        expected = graph[config["expected_organization"]]
        expected.should == config["expected_organization_dependencies"]
      end
    end

    it "gathers dependencies for a user" do
      graph = RepoDependencyGraph.send(:dependencies, :user => "repo-test-user", :token => config["token"])
      graph.should == {"repo_a"=>[["repo_b"], ["repo_c"]], "repo_c"=>[["repo_b"]]}
    end

    it "finds nothing for private when all repos are public" do
      graph = RepoDependencyGraph.send(:dependencies, :user => "repo-test-user", :private => true, :token => config["token"])
      graph.should == {}
    end

    it "can filter" do
      graph = RepoDependencyGraph.send(:dependencies, :user => "repo-test-user", :select => /_b|a/, :token => config["token"])
      graph.should == {"repo_a"=>[["repo_b"]]}
    end

    it "can reject" do
      graph = RepoDependencyGraph.send(:dependencies, :user => "repo-test-user", :reject => /_c/, :token => config["token"])
      graph.should == {"repo_a"=>[["repo_b"]]}
    end

    it "gathers chef dependencies for a user" do
      graph = RepoDependencyGraph.send(:dependencies, :user => "repo-test-user", :chef => true, :token => config["token"])
      graph.should == {"chef_a"=>[["chef_b", "~> 0.1"], ["chef_c", "~> 0.1"]], "chef_c"=>[["chef_b", "~> 0.1"]]}
    end

    it "can include external dependencies" do
      graph = RepoDependencyGraph.send(:dependencies, :user => "repo-test-user", :external => true, :token => config["token"])
      graph.should == {"repo_a"=>[["repo_b"], ["repo_c"]], "repo_c"=>[["repo_b"], ["activesupport"]]}
    end

    it "can map repo names so misnamed repos can be found as internal" do
      graph = RepoDependencyGraph.send(:dependencies, :user => "repo-test-user", :map => [/repo_(c|d)/, "activesupport"], :token => config["token"])
      graph.should == {"repo_a"=>[["repo_b"]], "repo_c"=>[["repo_b"], ["activesupport"]]}
    end

    it "can map repo names to nothing" do
      graph = RepoDependencyGraph.send(:dependencies, :user => "repo-test-user", :map => [/repo_/], :token => config["token"])
      graph.should == {}
    end

    it "prevents silly map and external" do
      expect {
        RepoDependencyGraph.send(:dependencies, :user => "repo-test-user", :map => [/repo_(c|d)/, "activesupport"], :external => true, :token => config["token"])
      }.to raise_error(/internal/)
    end
  end

  context ".scan_gemfile" do
    def call(*args)
      RepoDependencyGraph.send(:scan_gemfile, *args)
    end

    it "finds nothing" do
      call("").should == []
    end

    it "finds without version" do
      call("gem 'foo'").should == [["foo"]]
    end

    it "finds with version" do
      call("gem 'foo', '1.2.3'").should == [["foo", "1.2.3"]]
    end

    it "finds ref with 1.8 syntax" do
      call("gem 'foo', :ref => 'abcd'").should == [["foo", "abcd"]]
      call("gem 'foo'  ,:ref=>'abcd'").should == [["foo", "abcd"]]
    end

    it "finds ref with 1.9 syntax" do
      call("gem 'foo', ref: 'abcd'").should == [["foo", "abcd"]]
      call("gem 'foo',ref:'abcd'").should == [["foo", "abcd"]]
    end
  end

  context ".scan_chef_metadata" do
    def call(*args)
      RepoDependencyGraph.send(:scan_chef_metadata, *args)
    end

    it "finds nothing" do
      call("").should == []
    end

    it "finds without version" do
      call("depends 'foo'").should == [["foo"]]
    end

    it "finds with version" do
      call("depends 'foo', '1.2.3'").should == [["foo", "1.2.3"]]
    end
  end

  context ".scan_gemfile_lock" do
    def call(*args)
      RepoDependencyGraph.send(:scan_gemfile_lock, *args)
    end

    it "finds without version" do
      content = <<-LOCK.gsub(/^        /, "")
        GEM
          remote: https://rubygems.org/
          specs:
            bump (0.5.0)
            diff-lcs (1.2.5)
            json (1.8.1)
            organization_audit (1.0.4)
              json
            rspec (2.14.1)
              rspec-core (~> 2.14.0)
              rspec-expectations (~> 2.14.0)
              rspec-mocks (~> 2.14.0)
            rspec-core (2.14.7)
            rspec-expectations (2.14.5)
              diff-lcs (>= 1.1.3, < 2.0)
            rspec-mocks (2.14.5)

        PLATFORMS
          ruby

        DEPENDENCIES
          bump
          rspec (~> 2)
          organization_audit
      LOCK
      call(content).should == [
        ["bump", "0.5.0"],
        ["diff-lcs", "1.2.5"],
        ["json", "1.8.1"],
        ["organization_audit", "1.0.4"],
        ["rspec", "2.14.1"],
        ["rspec-core", "2.14.7"],
        ["rspec-expectations", "2.14.5"],
        ["rspec-mocks", "2.14.5"]
      ]
    end

    it "finds ref" do
      content = <<-LOCK.gsub(/^        /, "")
        GIT
          remote: git@github.com:foo/bar.git
          revision: 891e256a0364079a46259b3fda9c68f816bbe24c
          specs:
            barz (0.0.4)
              json

        GEM
          remote: https://rubygems.org/
          specs:
            json (1.8.1)

        PLATFORMS
          ruby

        DEPENDENCIES
          barz!
      LOCK
      call(content).should == [
        ["barz", "0.0.4"],
        ["json", "1.8.1"]
      ]
    end
  end

  context ".draw" do
    it "draws" do
      Dir.mktmpdir do
        Dir.chdir do
          RepoDependencyGraph.send(:draw, "foo" => ["bar"])
          File.exist?("out.png").should == true
        end
      end
    end
  end

  context ".color" do
    it "calculates for 1 to max" do
      values = [1,2,25,50,51]
      values.map do |k,v|
        [k, RepoDependencyGraph.send(:color, k, values.min..values.max)]
      end.should == [[1, "#80f31f"], [2, "#89ef19"], [25, "#fd363f"], [50, "#492efa"], [51, "#3f36fd"]]
    end
  end

  context ".load_spec" do
    it "loads simple spec" do
      spec = RepoDependencyGraph.send(:load_spec, <<-RUBY)
        Gem::Specification.new "foo" do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
    end

    it "loads spec with require" do
      spec = RepoDependencyGraph.send(:load_spec, <<-RUBY)
        require 'asdadadsadas'
        Gem::Specification.new "foo" do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
    end

    it "loads spec with VERSION" do
      spec = RepoDependencyGraph.send(:load_spec, <<-RUBY)
        Gem::Specification.new "foo", Foo::VERSION do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
      spec.version.to_s.should == "1.2.3"
    end

    it "loads spec with VERSION::STRING" do
      spec = RepoDependencyGraph.send(:load_spec, <<-RUBY)
        Gem::Specification.new "foo", Foo::VERSION::STRING do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
      spec.version.to_s.should == "1.2.3"
    end

    it "leaves Gem::Version alone" do
      spec = RepoDependencyGraph.send(:load_spec, <<-RUBY)
        Gem::Version.new("1.1.1") || Gem::VERSION
        Gem::Specification.new "foo", Foo::VERSION::STRING do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
      spec.version.to_s.should == "1.2.3"
    end

    it "does not modify $LOAD_PATH" do
      expect {
        RepoDependencyGraph.send(:load_spec, <<-RUBY)
          $LOAD_PATH << "xxx"
          $:.unshift "xxx"
          Gem::Specification.new "foo", Foo::VERSION do |s|
            s.add_runtime_dependency "xxx", "1.1.1"
          end
        RUBY
      }.to_not change { $LOAD_PATH }
    end

    it "loads spec with File.read" do
      spec = RepoDependencyGraph.send(:load_spec, <<-RUBY)
        Gem::Specification.new "foo", File.read("VERSION") do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
      spec.version.to_s.should == "1.2.3"
    end

    it "loads spec with File.read from unknown file (travis-ci)" do
      spec = RepoDependencyGraph.send(:load_spec, <<-RUBY)
        File.read(foooo) =~ /\\bVERSION\\s*=\\s*["'](.+?)["']/
        version = \$1
        Gem::Specification.new "foo", version do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
      spec.version.to_s.should == "1.2.3"
    end

    it "loads spec with IO.read" do
      spec = RepoDependencyGraph.send(:load_spec, <<-RUBY)
        Gem::Specification.new "foo", IO.read("VERSION") do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
      spec.version.to_s.should == "1.2.3"
    end

    it "returns nil on error" do
      silence_stderr do
        RepoDependencyGraph.send(:load_spec, "raise").should == nil
      end
    end
  end

  context ".parse_options" do
    def call(argv, keep_defaults=false)
      result = RepoDependencyGraph.send(:parse_options, argv)
      result.delete(:user) unless keep_defaults
      result
    end

    it "uses current user by default" do
      result = call([], true)
      result.keys.should == [:user]
    end

    it "parses --user" do
      call(["--user", "foo"], true).should == {:user => "foo"}
    end

    it "parses --organization" do
      call(["--organization", "foo"]).should == {:organization => "foo"}
    end

    it "parses --token" do
      call(["--token", "foo"]).should == {:token => "foo"}
    end

    it "parses --private" do
      call(["--private"]).should == {:private => true}
    end

    it "parses --external" do
      call(["--external"]).should == {:external => true}
    end

    it "parses --chef" do
      call(["--chef"]).should == {:chef => true}
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
