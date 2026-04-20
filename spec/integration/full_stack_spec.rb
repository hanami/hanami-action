# frozen_string_literal: true

require "rack/test"

RSpec.describe "Full stack application" do
  include Rack::Test::Methods

  def app
    FullStack::Application.new
  end

  before do
    pending
  end

  it "passes action inside the Rack env" do
    get "/", {}, "HTTP_ACCEPT" => "text/html"

    expect(last_response.body).to include("FullStack::Controllers::Home::Index")
    expect(last_response.body).to include(':greeting=>"Hello"')
  end

  it "only allows entity headers if the request is HEAD" do
    head "/head", {}, "HTTP_ACCEPT" => "text/html"

    expect(last_response.body).to be_empty
    expect(last_response.headers.keys).to_not include("X-Renderable")
  end

  it "in case of redirect and invalid params, it passes errors in session and then deletes them" do
    post "/books", title: ""
    follow_redirect!

    expect(last_response.body).to include("FullStack::Controllers::Books::Index")
    expect(last_response.body).to include("params: {}")

    get "/books"
    expect(last_response.body).to include("params: {}")
  end

  it "uses flash to pass informations" do
    get "/poll"
    follow_redirect!

    expect(last_response.body).to include("FullStack::Controllers::Poll::Step1")
    expect(last_response.body).to include("Start the poll")

    post "/poll/1", {}
    follow_redirect!

    expect(last_response.body).to include("FullStack::Controllers::Poll::Step2")
    expect(last_response.body).to include("Step 1 completed")
  end

  it "doesn't return stale informations when using redirect" do
    post "/settings", {}
    follow_redirect!

    expect(last_response.body).to match(/Hanami::Action::Flash:0x[\d\w]* {:data=>{}, :kept=>{"message"=>"Saved!"}}/)

    get "/settings"

    expect(last_response.body).to match(/Hanami::Action::Flash:0x[\d\w]* {:data=>{}, :kept=>{}}/)
  end

  it "doesn't return stale informations when not using redirect" do
    get "/poll/1"
    expect(last_response.body).to match(/Hanami::Action::Flash:0x[\d\w]* {:data=>{:notice=>"Start the poll"}, :kept=>{}}/)

    get "/settings"
    expect(last_response.body).to match(/Hanami::Action::Flash:0x[\d\w]* {:data=>{}, :kept=>{}}/)
  end

  it "can access params with string symbols or methods" do
    patch "/books/1", book: {
      title: "Hanami in Action",
      author: {
        name: "Luca",
        favourite_colour: "purple"
      }
    }
    result = JSON.parse(last_response.body, symbolize_names: true)
    expect(result).to eq(
      symbol_access: "Luca",
      valid: true,
      errors: {}
    )
  end

  it "validates nested params" do
    patch "/books/1", book: {
      title: "Hanami in Action"
    }
    result = JSON.parse(last_response.body, symbolize_names: true)
    expect(result[:valid]).to  be(false)
    expect(result[:errors]).to eq(book: {author: ["is missing"]})
  end

  it "redirect in before action and call action method is not called" do
    get "users/1"

    expect(last_response.status).to be(302)
    expect(last_response.body).to   eq("Found") # This message is 302 status
  end
end
