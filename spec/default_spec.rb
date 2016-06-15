require 'spec_helper'

describe BetterChefRundeck do
  # it 'has a version number' do
  #   expect(BetterChefRundeck::VERSION).not_to be nil
  # end

  # it 'does something useful' do
  #   expect(false).to eq(true)
  # end
end

describe "My Sinatra Application" do
  it '/ should respond ok' do
    get '/'
    expect(last_response).to be_ok
  end
end
