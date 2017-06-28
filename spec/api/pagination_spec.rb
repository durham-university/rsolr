require 'spec_helper'

RSpec.describe RSolr::Client do
  let(:connection) { nil }
  let(:connection_options) { {} }
  let(:client) do
    RSolr::Client.new connection, connection_options
  end
  
  
  context "build_paginated_request" do
    let(:params) { { q: 'test' } }
    let(:page) { 3 }
    let(:per_page) { 25 }
    let(:subject) { client.build_paginated_request(page, per_page, "select", {params: params})}
    it "should create the proper solr params and query string" do
      expect(subject[:params]["start"]).to eq(50)
      expect(subject[:params]["rows"]).to eq(25)
      expect(subject[:uri].query).to match(/rows=25/)
      expect(subject[:uri].query).to match(/start=50/)
    end
    
    it "shouldn't modify given params hash" do
      expect(subject[:params]["start"]).to eq(50)
      expect(subject[:params]["rows"]).to eq(25)
      expect(params[:start]).to be_nil
      expect(params['start']).to be_nil
      expect(params[:rows]).to be_nil
      expect(params['rows']).to be_nil
    end
    
    context "when rows and limit are set" do
      let(:rows) { 80 }
      let(:start) { 25 }
      let(:params) { { q: 'test', rows: rows, start: start } }
      
      it "should offset start param" do
        expect(subject[:params]['start']).to eq(75)
        expect(subject[:params]['rows']).to eq(25)
        expect(subject[:uri].query).to match(/rows=25/)
        expect(subject[:uri].query).to match(/start=75/)
      end
      
      context "when limit is reached" do
        let(:page) { 4 }
        it "it should clamp rows param" do
          expect(subject[:params]['start']).to eq(100)
          expect(subject[:params]['rows']).to eq(5)
          expect(subject[:uri].query).to match(/rows=5/)
          expect(subject[:uri].query).to match(/start=100/)
        end
      end
    end
    
  end
  context "paginate" do
    it "should build a paginated request context and call execute" do
      expect(client).to receive(:execute).with(hash_including({
        #:page => 1,
        #:per_page => 10,
        :params => {
          "rows" => 10,
          "start" => 0,
          :wt => :json
        }
      }))
      client.paginate 1, 10, "select"
    end
    it "should accept start and rows params" do
      expect(client).to receive(:execute)
      client.paginate 1, 10, "select", {params: { 'rows' => 100, 'start' => 10}}
    end
  end
end