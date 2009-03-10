require 'test_helper'

class MonkeyPatchTest < Test::Unit::TestCase
  should "convert a hash to a valid url parameter string" do
    h1 = { :foo => 1, :bar => 2, :baz => 3 }
    assert_equal h1.to_url, 'foo=1&bar=2&baz=3'

    h2 = { :foo => "What's up Doc", :bar => "1" }
    assert_equal h2.to_url, "foo=What%27s+up+Doc&bar=1"
  end
end
