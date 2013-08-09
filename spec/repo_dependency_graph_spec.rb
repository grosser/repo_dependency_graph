require "spec_helper"

describe RepoDependencyGraph do
  it "has a VERSION" do
    RepoDependencyGraph::VERSION.should =~ /^[\.\da-z]+$/
  end
end
