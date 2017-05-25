require "spec_helper"

describe RepoDependencyGraph do
  it "has a VERSION" do
    RepoDependencyGraph::VERSION.should =~ /^[\.\da-z]+$/
  end

  context ".dependencies" do
    let(:defaults) {{ :only => "gem", :user => "repo-test-user", :token => config["token"] }}

    def call(options={})
      RepoDependencyGraph.send(:dependencies, defaults.merge(options))
    end

    before do
      RepoDependencyGraph.stub(:puts)
    end

    it "gathers dependencies for private organizations" do
      pending unless config["user"]
      graph = call(
        :organization => config["organization"],
        :select => Regexp.new(config["expected_organization_select"])
      )
      expected = graph[config["expected_organization"]]
      expected.should == config["expected_organization_dependencies"]
    end

    it "gathers dependencies for a user" do
      call.should == {"repo_a"=>[["repo_b"], ["repo_c"]], "repo_c"=>[["repo_b"]]}
    end

    it "finds nothing for private when all repos are public" do
      call(:private => true).should == {}
    end

    it "can filter" do
      call(:select => /_b|a/).should == {"repo_a"=>[["repo_b"]]}
    end

    it "can reject" do
      call(:reject => /_c/).should == {"repo_a"=>[["repo_b"]]}
    end

    it "gathers chef dependencies for a user" do
      call(:only => "chef").should == {"chef_a"=>[["chef_b", "~> 0.1"], ["chef_c", "~> 0.1"]], "chef_c"=>[["chef_b", "~> 0.1"]]}
    end

    it "can include external dependencies" do
      call(:external => true).should == {"repo_a"=>[["repo_b"], ["repo_c"]], "repo_c"=>[["repo_b"], ["activesupport"]]}
    end

    it "can map repo names so misnamed repos can be found as internal" do
      call(:map => [/repo_(c|d)/, "activesupport"]).should == {"repo_a"=>[["repo_b"]], "repo_c"=>[["repo_b"], ["activesupport"]]}
    end

    it "can map repo names to nothing" do
      call(:map => [/repo_/]).should == {}
    end

    it "prevents silly map and external" do
      expect {
        call(:map => [/repo_(c|d)/, "activesupport"], :external => true)
      }.to raise_error(/internal/)
    end
  end

  context ".scan_gemfile" do
    def call(*args)
      RepoDependencyGraph.send(:scan_gemfile, 'foo', *args)
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
      RepoDependencyGraph.send(:scan_chef_metadata, 'foo', *args)
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
      RepoDependencyGraph.send(:scan_gemfile_lock, 'foo', *args)
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

    it "returns nil on error" do
      Bundler::LockfileParser.should_receive(:new).and_raise
      silence_stderr do
        call("bad").should == nil
      end
    end
  end

  context ".load_gemspec" do
    def call(*args)
      RepoDependencyGraph.send(:load_gemspec, 'foo', *args)
    end

    it "loads simple spec" do
      spec = call(<<-RUBY)
        Gem::Specification.new "foo" do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
    end

    it "loads spec with require" do
      spec = call(<<-RUBY)
        require 'asdadadsadas'
        Gem::Specification.new "foo" do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
    end

    it "loads spec with require_relative" do
      spec = call(<<-RUBY)
        require_relative 'asdadadsadas'
        Gem::Specification.new "foo" do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
    end

    it "loads spec with VERSION" do
      spec = call(<<-RUBY)
        Gem::Specification.new "foo", Foo::VERSION do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
      spec.version.to_s.should == "1.2.3"
    end

    it "loads spec with VERSION::STRING" do
      spec = call(<<-RUBY)
        Gem::Specification.new "foo", Foo::VERSION::STRING do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
      spec.version.to_s.should == "1.2.3"
    end

    it "leaves Gem::Version alone" do
      spec = call(<<-RUBY)
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
        call(<<-RUBY)
          $LOAD_PATH << "xxx"
          $:.unshift "xxx"
          Gem::Specification.new "foo", Foo::VERSION do |s|
            s.add_runtime_dependency "xxx", "1.1.1"
          end
        RUBY
      }.to_not change { $LOAD_PATH }
    end

    it "loads spec with File.read" do
      spec = call(<<-RUBY)
        Gem::Specification.new "foo", File.read("VERSION") do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
      spec.version.to_s.should == "1.2.3"
    end

    it "loads spec with File.read from unknown file (travis-ci)" do
      spec = call(<<-RUBY)
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
      spec = call(<<-RUBY)
        Gem::Specification.new "foo", IO.read("VERSION") do |s|
          s.add_runtime_dependency "xxx", "1.1.1"
        end
      RUBY
      spec.name.should == "foo"
      spec.version.to_s.should == "1.2.3"
    end

    it "returns nil on error" do
      silence_stderr do
        call("raise").should == nil
      end
    end
  end
end
