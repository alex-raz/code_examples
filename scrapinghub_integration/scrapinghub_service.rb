# Service object for interacting with scrapinghub.com API
#
# usage:
# Production/Development: ScrapinghubService.new.fetch_new_records
# Test:                   ScrapinghubService.new('fake_api_key').fetch_new_records
# warn: real api key leads to uploading more than 12000 Products records
class ScrapinghubService
  attr_reader :api_key, :base_url

  # TODO: replace fake_api_key here with something from secrets.yml or with ENV['variable']
  def initialize(api_key = 'fake_api_key')
    @api_key = api_key
    @base_url = 'https://app.scrapinghub.com/api'
  end

  def fetch_new_records
    projects = fetch_project_ids
    return unless projects&.any?

    projects.each do |project_id|
      jobs = fetch_jobs(project_id)

      jobs.each do |job|
        handle_job_item(job)
      end
    end
  end

  private

  def handle_job_item(job)
    job_id = job['id']
    return if ShJob.find_by(sh_job_id: job_id)

    ShJob.create!(sh_job_id: job_id)

    return if job['items_scraped'] == 0 # no needed to parse jobs without items

    products = fetch_products(job_id)
    return unless products.any?

    products.each do |product|
      handle_product_item(product)
    end
  end

  def handle_product_item(item)
    return if Product.find_by(original_url: item['original_url'])

    # TODO:
    # following product attributes have no direct mapping with api responses:
    # # 'active', 'daily_order', 'discount', 'image_content_type', 'image_file_name',
    # # 'image_file_size', 'image_updated_at', 'sale_date', 'time_window_id', 'url'
    # (I've checked this on 12000 product items)

    product = Product.new(
      active: item['active'],
      brand: item['brand'],
      category_id: item['category_id'],
      daily_order: item['daily_order'],
      description: item['description'],
      discount: item['discount'],
      image_content_type: item['image_content_type'],
      image_file_name: item['image_file_name'],
      image_file_size: item['image_file_size'],
      image_updated_at: item['image_updated_at'],
      name: item['Name'],
      original_url: item['original_url'],
      reg_price: item['reg_price'],
      sale_date: item['sale_date'],
      sale_price: item['sale_price'],
      temp_image_url: build_temp_image_url(item),
      time_window_id: item['time_window_id'],
      url: item['url'],
      website_id: item['website_id']
    )

    product.save
  end

  # TODO: most likely, this will not lead to image saving
  # sorry, but I need a bit more details to get this to work
  def build_temp_image_url(item)
    return nil unless item['temp_image_url']

    base = 'https://s3.amazonaws.com/shopscenes/product_images/'
    path = item['temp_image_url'][0]['path']
    base + path
  end

  def fetch_products(job_id)
    job_items_url =
      "https://storage.scrapinghub.com/items/#{job_id}?apikey=#{api_key}&format=json"

    read_url_to_json(job_items_url)
  end

  def fetch_jobs(project_id)
    jobs_url_string =
      "#{base_url}/jobs/list.json?apikey=#{api_key}&state=finished&project=#{project_id}"
    response = read_url_to_json(jobs_url_string)

    response['jobs']
  end

  def fetch_project_ids
    projects_list_url = "#{base_url}/scrapyd/listprojects.json?apikey=#{api_key}"
    return unless response = read_url_to_json(projects_list_url)

    response['projects']
  end

  # TODO: think about exceptions handling
  def read_url_to_json(url_string)
    response = open_url(url_string).to_s
    JSON.parse(response)

    rescue JSON::ParserError => e
      Rails.logger.info "Unable to parse Scrapinghub response. Original exception was: #{e}"
      return nil
  end

  # TODO: you might want to replace 'open-uri' with something like Faraday, or RestClient
  # I've decided to use 'open-uri' just to reduce amount of 3-party dependencies
  #
  # TODO: think about exceptions handling
  def open_url(url_string)
    require 'open-uri'

    open(url_string).read

    rescue OpenURI::HTTPError => e
      Rails.logger.info "Unable to open Scrapinghub url: #{url_string}. Original exception was: #{e}"
      return nil
  end
end

class ScrapinghubAPIError < StandardError; end
