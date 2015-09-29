require 'spec_helper'

describe 'flagged item modal', js: true do

  before(:each) do
    visit solr_document_path(:id => 'bpl-dev:00000007x')
  end

  it 'should display the flagged item modal when the page is loaded' do
    expect(page).to have_selector('#flagged_warning')
  end

  it 'should return to the search page when the "back" button is clicked' do
    click_link('Back to Search')
    expect(page).to have_selector('#basic_search')
  end

  it 'should close the flagged item modal when the accept button is clicked' do
    click_button('View Content')
    expect(page).not_to have_selector('#flagged_warning')
  end

end