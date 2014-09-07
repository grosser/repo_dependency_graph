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
      {"token" => "f8a52fb5411511fb7b93b9729794dc753e6bafae"} # tome from user: some-token -> higher rate limits
    end
  end
end

RSpec.configure do |c|
  c.include SpecHelpers
end
