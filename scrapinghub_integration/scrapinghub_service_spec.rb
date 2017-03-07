require 'rails_helper'

RSpec.describe ScrapinghubService, type: :service do
  describe 'jobs list' do
    let(:key) { 'fake_api_key' }

    def fetch_new_records
      described_class.new(key).fetch_new_records
    end

    def stub_projects_request
      stub_request(:get, "https://app.scrapinghub.com/api/scrapyd/listprojects.json?apikey=#{key}").
        to_return(status: 200, body: '{"status":"ok","projects":[666]}', headers: {})
    end

    def stub_jobs_request_response(jobs)
      url =
        "https://app.scrapinghub.com/api/jobs/list.json?apikey=#{key}&state=finished&project=666"
      simplified_responce_body =
        "{\"status\": \"ok\", \"total\": 2, \"count\": 2, \"jobs\": #{jobs}}"
      stub_request(:get, url).to_return(status: 200, body: simplified_responce_body, headers: {})
    end

    def stub_items_request_response(job_id:, products:)
      items_request_url =
        "https://storage.scrapinghub.com/items/#{job_id}?apikey=#{key}&format=json"
      stub_request(:get, items_request_url).
        to_return(status: 200, body: products, headers: {})
    end

    before { stub_projects_request }

    context 'when already has some jobs' do
      it 'saves only new jobs' do
        stub_jobs_request_response('[
          {"id": "existing_job", "items_scraped": 2},
          {"id": "new_job", "items_scraped": 2}
        ]')
        stub_items_request_response(job_id: 'new_job', products: '[]')

        create(:sh_job, sh_job_id: 'existing_job')

        expect{ fetch_new_records }.to change(ShJob, :count).by(1)
        expect(ShJob.last.sh_job_id).to eq 'new_job'
      end

      it 'handles only products from new jobs' do
        stub_jobs_request_response('[
          {"id": "existing_job", "items_scraped": 2},
          {"id": "new_job", "items_scraped": 2}
        ]')
        stub_items_request_response(
          job_id: 'new_job',
          products: '[
            {"Name":"ProductFromNewJob","original_url":"http://example.com/product_from_new_job"}
          ]'
        )
        stub_items_request_response(
          job_id: 'existing_job',
          products: '[
            {"Name":"ProductFromExistingJob","original_url":"http://example.com/anything"}
          ]'
        )
        create(:sh_job, sh_job_id: 'existing_job')

        expect{ fetch_new_records }.to change(Product, :count).by(1)
        expect(Product.last.name).to eq 'ProductFromNewJob'
      end

      it 'attempts to save image' do
        stub_jobs_request_response('[
          {"id": "new_job", "items_scraped": 1}
        ]')
        stub_items_request_response(
          job_id: 'new_job',
          products: '[
            {
              "Name":"Product with image",
              "original_url":"http://example.com/product",
              "temp_image_url":[{
                "url":"http://guite.long/url",
                "path":"full/weird_hash_like_thing.jpg",
                "checksum":"one_more_hash_like_thing"
              }]
            }
          ]'
        )

        instance = instance_double(Product)
        expect(instance).to receive(:save)
        expect(Product).to receive(:new).with(
          active: nil,
          brand: nil,
          category_id: nil,
          daily_order: nil,
          description: nil,
          discount: nil,
          image_content_type: nil,
          image_file_name: nil,
          image_file_size: nil,
          image_updated_at: nil,
          name: 'Product with image',
          original_url: 'http://example.com/product',
          reg_price: nil,
          sale_date: nil,
          sale_price: nil,
          temp_image_url: "https://s3.amazonaws.com/shopscenes/product_images/full/weird_hash_like_thing.jpg",
          time_window_id: nil,
          url: nil,
          website_id: nil
        ).and_return(instance)

        fetch_new_records
      end

      context 'when product already exist' do
        it "handles only new products" do
          stub_jobs_request_response('[
            {"id": "new_job", "items_scraped": 2}
          ]')
          stub_items_request_response(
            job_id: 'new_job',
            products: '[
              {"Name":"New Product","original_url":"THE_SAME"},
              {"Name":"Product Double","original_url":"THE_SAME"}
            ]'
          )

        expect{ fetch_new_records }.to change(Product, :count).by(1)
        expect(Product.last.name).to eq 'New Product'
        end
      end
    end

    context 'when has no new jobs' do
      it 'does just nothing' do
        stub_jobs_request_response('[
          {"id": "existing_job", "items_scraped": 2}
        ]')

        create(:sh_job, sh_job_id: 'existing_job')

        expect{ fetch_new_records }.not_to change(ShJob, :count)
        expect{ fetch_new_records }.not_to change(Product, :count)
      end
    end
  end
end
