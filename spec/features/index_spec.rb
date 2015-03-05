PEOPLE_BUTTON = '[data-map-type="PeopleMap"]'
REFERENCES_BUTTON = '[data-map-type="ReferencesMap"]'
CHARACTERISTICS_BUTTON = '[data-map-type="CharacteristicsMap"]'

describe 'the front page', type: :feature do

  before(:each) do
    visit '/'
  end

  describe 'people button' do

    it 'exists' do
      expect(page).to have_css(PEOPLE_BUTTON)
    end

    it 'is active by default', js: true do
      expect(page).to have_css("#{PEOPLE_BUTTON}.active")
    end

  end

  describe 'references button' do

    it 'exists' do
      expect(page).to have_css(REFERENCES_BUTTON)
    end

    it 'is NOT active by default', js: true do
      expect(page).not_to have_css("#{REFERENCES_BUTTON}.active")
    end

  end

  describe 'characteristics button' do

    it 'exists' do
      expect(page).to have_css(CHARACTERISTICS_BUTTON)
    end

    it 'is NOT active by default', js: true do
      expect(page).not_to have_css("#{CHARACTERISTICS_BUTTON}.active")
    end

  end

end