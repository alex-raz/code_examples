module FeatureHelpers
  def visit_pricing_page
    visit pricing_path
    within('#page-title-block') { expect(page).to have_text('Pricing') }
  end

  def stripe_checkout(email:, card_number: '4242424242424242', expiry: '04/44', cvc: '666')
    within_frame('stripe_checkout_app') do
      fill_in 'Email', with: email
      fill_in 'Name', with: 'Test User'
      fill_in 'Street', with: 'Test Street'
      fill_in 'City', with: 'Test City'
      fill_in 'Postcode', with: 'Test Postcode'
      click_button 'Payment Info'

      fill_in 'Card number', with: card_number
      fill_in 'Expiry', with: expiry
      fill_in 'CVC', with: cvc
      click_button 'Purchase'
    end
  end

  def click_on_get_started_now
    click_link 'Get Started Now'
  end

  def setup_book_design
    within(find_all('.js-book_style_link').first) do
      find('.our-work-1-overlay').click
    end
    within('form#templateSelectForm') do
      fill_in 'Line 1', with: 'First line'
      fill_in 'Line 2', with: 'Second line'
      click_on 'Select & Save'
    end
    expected_template_attrs = {
      'template_id' => 'The Easy Modern',
      'template_title' => "First line\nSecond line\n"
    }
    expect(
      Book.last.attributes.slice('template_id', 'template_title')
    ).to eq(expected_template_attrs)
  end

  def fill_in_and_submit_story_form(title: 'Test', year: '1990', body: 'Lorem Ipsum', path_to_file: nil)
    within('form#new_story') do
      fill_in 'story[title]', with: title
      fill_in 'story[year]', with: year
      fill_in 'story[body]', with: body

      if path_to_file
        # a small hack to make file input visible for 'attach_file' action
        page.execute_script("$('input[name=" + '"story[image1]"' + "]'" + ').removeClass("hide")')

        attach_file 'story[image1]', path_to_file
      end

      click_button 'Add Story'
    end

    within('#storyboard-timeline') do
      expect(page).to have_text("#{title} - #{year}")

      story = User.last.books.last.stories.last
      expect(story.title).to eq(title)

      if path_to_file
        expect(story.image1_file_name).to eq('iogeg-big.jpg')
        expect(File.exist?(story.image1.path)).to be true
      end
    end
  end

  def submit_book_name(book_name:)
    within('form.edit_book') do
      fill_in 'book_name', with: book_name
      click_on 'Proceed'
    end

    expect(page).to have_text("Book #{book_name} has been created.")
    expect(User.last.books.last.name).to eq(book_name)
  end

  def submit_book
    click_link 'Submit Book'
    within('form.edit_book') { click_on 'Submit!' }
    expect(page).to have_text('Congratulations! Your book has been submitted.')
  end

  def submit_create_password_form(password)
    within('form#new_user') do
      fill_in 'Create password', with: password
      fill_in 'Confirm password', with: password
      click_on 'Create Password'
    end
  end

  def submit_sign_in_form(password)
    within('form#new_user') do
      fill_in 'Password', with: password
      click_on 'Sign in'
    end
  end

  def check_resulting_book_attrs(name:, user_email:)
    book = Book.last
    expected_book_attrs = {
      'name' => name,
      'template_id' => "The Easy Modern",
      'address_line1' => "Test Street",
      'city' => "Test City",
      'zip' => "Test Postcode",
      'template_title' => "First line\nSecond line\n",
      'submitted' => true
    }
    expected_user = User.find_by!(email: user_email)

    expect(
      book.attributes.slice(
        'name', 'template_id', 'address_line1', 'city', 'zip', 'template_title', 'submitted'
      )
    ).to eq(expected_book_attrs)
    expect(book.user).to eq(expected_user)
  end
end
