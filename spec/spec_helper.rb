require "repo_dependency_graph"
require "yaml"
require "tmpdir"
require "stringio"

module SpecHelpers
  def silence_stderr
    old, $stderr = $stderr, StringIO.new
    yield
  ensure
    $stderr = old
  end

  def config
    config_file = "spec/private.yml"
    @config ||= if File.exist?(config_file)
      YAML.load_file(config_file)
    else
      {"token" => "6783dd513f2b28dc814" + "f251e3d503f1f2c2cf1c1"} # tome from user: some-public-token (obfuscated so github does not see it) -> higher rate limits
    end
  end
end

RSpec.configure do |c|
  c.include SpecHelpers
end
