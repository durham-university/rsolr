require 'spec_helper'
require 'json'

RSpec.describe RSolr::Response do
  let(:connection) { double('connection') }
  before { allow(connection).to receive(:send).and_return(mock_response) }
  let(:connection_options) { {} }
  let(:client) do
    RSolr::Client.new connection, connection_options
  end
  
  let(:mock_response) {
    double('response', status: '200', headers: [], body: JSON.dump(response_body))
  }
  let(:response_body) {
    {
      "responseHeader" => {
        "status" => 0, 
        "QTime" => 4, 
        "params" => {
          "q" => "title:\"test\"", 
          "fl" => "id title", 
          "start" => response_start.to_s, 
          "rows" => response_rows.to_s, 
          "wt" => "json"
        }
      }, 
      "response" => {
        "numFound" => response_total, 
        "start" => response_start, 
        "docs" => [response_rows, response_total - response_start].min.times.map do |i|
          {"id"=>"id#{i}", "title"=>"test #{i}"}
        end
      }, 
    }    
  }
  
  let(:response_start) { 0 }
  let(:response_rows) { 1000 }
  let(:response_total) { 20 }
  
  describe "response docs pagination" do
    let(:query_params) { {} }
    subject { client.paginate(page, per_page, "select", {params: query_params})["response"]["docs"] }
    
    context "when all in single page" do
      let(:page) { 1 }
      let(:per_page) { 1000 }
      it "reports all on single page" do
        expect(subject.current_page).to eq(1)
        expect(subject.total_pages).to eq(1)
        expect(subject.has_next?).to eq(false)
        expect(subject.has_previous?).to eq(false)
        expect(subject.previous_page).to eq(1)
        expect(subject.next_page).to eq(1)
      end
    end
    
    context "when many pages" do
      let(:page) { 2 }
      let(:per_page) { 6 }
      let(:response_rows) { 6 }
      let(:response_start) { 6 }
      it "gives correct paging information" do
        expect(subject.current_page).to eq(2)
        expect(subject.total_pages).to eq(4)
        expect(subject.has_next?).to eq(true)
        expect(subject.has_previous?).to eq(true)
        expect(subject.previous_page).to eq(1)
        expect(subject.next_page).to eq(3)
      end
    end
    
    context "when on last page" do
      let(:page) { 4 }
      let(:per_page) { 6 }
      let(:response_rows) { 2 }
      let(:response_start) { 18 }
      it "gives correct paging information" do
        expect(subject.current_page).to eq(4)
        expect(subject.total_pages).to eq(4)
        expect(subject.has_next?).to eq(false)
        expect(subject.has_previous?).to eq(true)
        expect(subject.previous_page).to eq(3)
        expect(subject.next_page).to eq(4)
      end
    end
    
    context "when using rows and start in params" do
      let(:query_params) { {rows: 10, start: 5} }
      
      context "when all in single page" do
        let(:page) { 1 }
        let(:per_page) { 1000 }
        let(:response_start) { 5 }
        let(:response_rows) { 10 }
        it "reports all on single page" do
          expect(subject.solr_start).to eq(5)
          expect(subject.page_start).to eq(0)
          expect(subject.solr_total).to eq(20)
          expect(subject.page_total).to eq(10)
          expect(subject.current_page).to eq(1)
          expect(subject.total_pages).to eq(1)
          expect(subject.has_next?).to eq(false)
          expect(subject.has_previous?).to eq(false)
          expect(subject.previous_page).to eq(1)
          expect(subject.next_page).to eq(1)
        end
      end
      
      context "when many pages" do
        let(:page) { 2 }
        let(:per_page) { 3 }
        let(:response_rows) { 3 }
        let(:response_start) { 8 } # params[:start] + (page-1)*per_page
        it "gives correct paging information" do
          expect(subject.current_page).to eq(2)
          expect(subject.total_pages).to eq(4)
          expect(subject.has_next?).to eq(true)
          expect(subject.has_previous?).to eq(true)
          expect(subject.previous_page).to eq(1)
          expect(subject.next_page).to eq(3)
        end
      end
      
      context "when on last page" do
        let(:page) { 4 }
        let(:per_page) { 3 }
        let(:response_rows) { 1 }
        let(:response_start) { 14 } # params[:start] + (page-1)*per_page
        it "gives correct paging information" do
          expect(subject.current_page).to eq(4)
          expect(subject.total_pages).to eq(4)
          expect(subject.has_next?).to eq(false)
          expect(subject.has_previous?).to eq(true)
          expect(subject.previous_page).to eq(3)
          expect(subject.next_page).to eq(4)
        end
      end
    end
  end

end