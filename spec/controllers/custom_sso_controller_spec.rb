require 'rails_helper'

RSpec.describe CustomSsoController, type: :controller do
  describe 'GET #login' do
    let(:secret_key) { 'test_secret_key' }
    let(:email) { 'test@example.com' }
    let(:timestamp) { Time.now.to_i }
    let(:payload) { { email: email, timestamp: timestamp }.to_json }
    let(:token) { Base64.encode64(payload) }
    let(:signature) { OpenSSL::HMAC.hexdigest('SHA256', secret_key, "#{email}#{timestamp}") }
    let!(:user) { create(:user, email: email) }

    before do
      allow(ENV).to receive(:fetch).with('SSO_SECRET_KEY').and_return(secret_key)
      allow(ENV).to receive(:fetch).with('CW_API_ONLY_SERVER', false).and_return(false)
    end

    it 'logs in the user and redirects to dashboard with valid credentials' do
      get :login, params: { signature: signature, token: token }
      
      expect(response).to redirect_to("/app/accounts/#{user.accounts.first.id}/dashboard")
      expect(controller.current_user).to eq(user)
    end

    it 'redirects to the provided redirect_url if strictly valid' do
      redirect_path = "/app/accounts/#{user.accounts.first.id}/settings/inboxes/list"
      get :login, params: { signature: signature, token: token, redirect_url: redirect_path }
      
      expect(response).to redirect_to(redirect_path)
    end
    
    it 'ignores redirect_url if it does not start with /' do
      get :login, params: { signature: signature, token: token, redirect_url: 'http://evil.com' }
      
      expect(response).to redirect_to("/app/accounts/#{user.accounts.first.id}/dashboard")
    end
  end
end
