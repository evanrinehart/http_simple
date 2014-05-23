require "http_simple"

def string &block
  x = yield
  raise "!" if !x.is_a?(String)
  puts "TEST PASSED"
end

def error e, &block
  begin
    yield
  rescue e
  else
    raise "!"
  end
  puts "TEST PASSED"
end

def network_error &block
  error HTTPSimple::NetworkException, &block
end

def not_found &block
  error HTTPSimple::NotFound, &block
end

string { HTTPSimple::get "http://example.com/" }
string { HTTPSimple::get "http://example.com/" }
string { HTTPSimple::get "https://example.com/" }
string do
  HTTPSimple::post "http://example.com/",
    body: '{"poke":null}',
    headers: {'Content-Type' => 'application/json'}
end
not_found { HTTPSimple::get "http://example.com/foo/bar/baz" }
network_error { HTTPSimple::get "http://asldkfnalskdfna.com/" }

