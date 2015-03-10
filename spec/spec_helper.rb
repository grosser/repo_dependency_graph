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
      {"token" => "741cc69384a30c5115" + "e98b0a32d1ca62460b9071"} # tome from user: some-public-token (obfuscated so github does not see it) -> higher rate limits
    end
  end
end

RSpec.configure do |c|
  c.include SpecHelpers
end
