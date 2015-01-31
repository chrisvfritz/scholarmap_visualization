describe 'the mock API documentation', type: :feature do

  before(:each) do
    visit "#{ScholarMapViz::API_BASE}/docs"
  end

  it 'exists' do
    expect(page.status_code).to be(200)
  end

  ScholarMapApiMock::ENDPOINTS.each do |endpoint|

    describe "the #{endpoint} documentation" do

      before(:each) do
        visit "#{ScholarMapViz::API_BASE}/docs/#{endpoint}"
      end

      it 'exists' do
        expect(page.status_code).to be(200)
      end

    end

  end


end