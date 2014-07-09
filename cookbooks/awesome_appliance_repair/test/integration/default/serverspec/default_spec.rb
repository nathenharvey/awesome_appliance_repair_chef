require 'serverspec'

include Serverspec::Helper::Exec
include Serverspec::Helper::DetectOS

RSpec.configure do |c|
  c.before :all do
    c.path = '/sbin:/usr/sbin'
  end
end

describe "awesome appliance repair" do
  it "does not display the default apache home page" do
    expect(command("curl http://localhost")).not_to return_stdout /Ubuntu/
  end

  it "displays the home page" do
    expect(command("curl http://localhost")).to return_stdout /Awesome/
  end
end
