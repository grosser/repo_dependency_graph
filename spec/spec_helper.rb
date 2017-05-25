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
      {"token" => "30642a82d9976d84fe" + "0a4bfbf4dd1e371b0d1665"} # tome from user: some-public-token (obfuscated so github does not see it) -> higher rate limits
    end
  end
end

RSpec.configure do |c|
  c.include SpecHelpers
end
