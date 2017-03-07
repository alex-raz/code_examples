require 'capybara_helper'

RSpec.feature 'Purchase a book', type: :feature do
  def visit_checkout_your_package
    within('.js-your_package') { click_on 'Purchase' }
    within('.js-checkout_purchase_btn') { click_on 'Purchase' }
  end

  def expected_emails(user_email:, book_name:)
    expect(SendGrid).to receive(:mail).with(user_email, :book_purchase, { token: anything })

    expect(SendGrid).to receive(:mail).with(
      'admin@example.com',
      'book_purchase_to_us',
      {
        user: user_email,
        timestamp: anything,
        codeorpaid: 'paid',
        giftorregular: 'regular',
        shipaddress: "Test Street\nTest City   Test Postcode",
        bookname: nil,
        booklink: anything
      }
    )

    expect(SendGrid).to receive(:mail).with(user_email, :book_submitted)

    expect(SendGrid).to receive(:mail).with(
      'admin@example.com',
      :book_submitted_to_us,
      {
        user: user_email,
        timestamp: anything,
        bookname: book_name,
        booklink: anything,
        yesornodigital: 'yes'
      }
    )
  end

  context 'when user has no account', js: true do
    context 'when succes payment' do
      let(:user_email) { 'test-user@example.com' }

      it 'user can create a book with stories and submit it to printing' do
        expected_emails(user_email: user_email, book_name: 'My first purchased book')

        visit_pricing_page
        visit_checkout_your_package

        stripe_checkout(email: user_email)
        expect(page).to have_text('Congratulations!')

        click_on_get_started_now
        submit_create_password_form('12345678')

        submit_book_name(book_name: 'My first purchased book')
        expect(page).to have_text('Book My first purchased book has been created.')
        expect(User.last.books.last.name).to eq('My first purchased book')

        setup_book_design

        # TODO: check\implement 'user cannot submit a book without stories' case

        fill_in_and_submit_story_form(
          title: 'Test story title',
          year: '1990',
          path_to_file: "#{Rails.root}/spec/fixtures/files/iogeg-big.jpg"
        )
        fill_in_and_submit_story_form(title: 'SecondStoryTitle', year: '1888')
        submit_book

        check_resulting_book_attrs(name: 'My first purchased book', user_email: user_email)
      end
    end

    context 'when failed payment' do
      let(:user_email) { 'test-user@example.com' }

      it 'user cannot create a book' do
        visit_pricing_page
        visit_checkout_your_package

        # '4100000000000019' card number is for
        # "Charge is declined with a 'card_declined' code and a 'fraudulent' reason"
        # see https://stripe.com/docs/testing#cards-responses for more details
        stripe_checkout(email: user_email, card_number: '4100000000000019')

        within('.alert-warning') { expect(page).to have_text('payment failed') }
        within('#page-title-block') { expect(page).to have_text('Pricing') }
        expect(User.last.books).to eq([])
      end
    end
  end

  context 'when user has an account', js: true do
    let(:user_email) { 'existing-user@example.com' }
    let(:user_pwd) { '12345678' }
    let(:existing_user) do
      create(:user, email: user_email, password: user_pwd, password_confirmation: user_pwd)
    end

    before { existing_user }

    context 'when success payment' do
      it 'user can create a book with story and submit it to printing' do
        expected_emails(user_email: user_email, book_name: 'One more book')

        visit_pricing_page
        visit_checkout_your_package

        stripe_checkout(email: user_email)
        expect(page).to have_text('Congratulations! You can start saving')

        click_on_get_started_now
        submit_sign_in_form(user_pwd)
        submit_book_name(book_name: 'One more book')
        setup_book_design
        fill_in_and_submit_story_form(title: 'FirstStoryTitle', year: '1888')
        submit_book
        check_resulting_book_attrs(name: 'One more book', user_email: user_email)
      end
    end

    context 'when failed payment' do
      it 'user cannot create a book' do
        visit_pricing_page
        visit_checkout_your_package

        # '4000000000000341' card number is for
        # "Attaching this card to a Customer object succeeds, but attempts to charge the customer fail."
        # see https://stripe.com/docs/testing#cards-responses for more details
        stripe_checkout(email: user_email, card_number: '4000000000000341')
        within('.alert-warning') { expect(page).to have_text('payment failed') }
        within('#page-title-block') { expect(page).to have_text('Pricing') }
        expect(User.last.books).to eq([])
      end
    end
  end
end
