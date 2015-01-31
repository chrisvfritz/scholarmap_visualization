PEOPLE_BUTTON_ID = '#people-button'
REFERENCES_BUTTON_ID = '#references-button'

describe 'the front page', type: :feature do

  before(:each) do
    visit '/'
  end

  describe 'people button' do

    it 'exists' do
      expect(page).to have_css(PEOPLE_BUTTON_ID)
    end

    it 'is active by default', js: true do
      expect(page).to have_css("#{PEOPLE_BUTTON_ID}.active")
    end

  end

  describe 'references button' do

    it 'exists' do
      expect(page).to have_css(REFERENCES_BUTTON_ID)
    end

    it 'is NOT active by default', js: true do
      expect(page).not_to have_css("#{REFERENCES_BUTTON_ID}.active")
    end

  end

end