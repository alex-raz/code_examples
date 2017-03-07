# Zanox.com doesn't have an API for affiliate programs
# and offers to download .csv files manually instead.
# A combo of Capybara and headless Webkit browser aims to replace (missing) API
require 'capybara'
require 'capybara/dsl'
require 'capybara/poltergeist'

module ZanoxService
  class Bot
    Capybara.run_server        = false
    Capybara.current_driver    = :poltergeist
    Capybara.javascript_driver = :poltergeist
    Capybara.app_host          = 'http://zanox.com'

    include Capybara::DSL

    def get_datafiles_links(shops)
      login_zanox_url = 'https://auth.zanox.com/login'
      zp_ext_id = SiteSettings.zanox_profile.ext_id
      page_with_active_programs =
        "https://marketplace.zanox.com/zanox/affiliate/#{zp_ext_id}/merchant-directory/index/tab/active"

      # login
      visit login_zanox_url
      if current_url == login_zanox_url # user may be already logged in
        fill_in 'loginForm.userName', with: ENV['ZANOX_USERNAME']
        fill_in 'loginForm.password', with: ENV['ZANOX_PASSWORD']
        find('span.inlineBlock').click
      end

      # fetch csv download link for each active shop (program)
      shop_links = {}
      shops.each do |shop|
        begin
          visit page_with_active_programs
          sleep 2 # just in case, we have to be sure that page has been loaded

          if shop_link = find('a', text: shop.title)
            shop_link.click

            begin
              find('a#productData').click

              # this is exactly why we need the Capybara here
              # link to .csv file shows only after evaluating some js code
              # required js has been found while inspecting of what happening in browser
              shop_links[shop.title] = evaluate_script('getJsfFormControl("CSV_Link").value')
            rescue Exception => e
              ZanoxImportLogger.info 'Unable to click on the "productData" link'
              ZanoxImportLogger.info "The original exception was: #{e}"
            end
          end
        rescue Exception => e
          ZanoxImportLogger.info "Shop '#{shop.title}' was not found"
          ZanoxImportLogger.info "The original exception was: #{e}"
        end
      end

      shop_links
    end
  end
end
